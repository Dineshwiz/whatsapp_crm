/**
 * Firebase Cloud Functions — Exotel WhatsApp Webhook
 * ✅ Fixed based on official Exotel API docs:
 *    - "to" and "from" must be in E.164 format: "+919876543210"
 *    - content must include recipient_type: "individual"
 *    - Firestore doc ID preserves the "+" prefix as Exotel sends it
 *
 * Firestore: settings/whatsapp
 *   apiKey, apiToken, accountSid, mobile (from-number), baseUrl (subdomain)
 */

const functions = require('firebase-functions');
const admin     = require('firebase-admin');
const axios     = require('axios');

admin.initializeApp();
const db = admin.firestore();

// ── Load credentials from Firestore — no hardcoding needed ────────────────
let _cachedSettings = null;

async function getSettings() {
  if (_cachedSettings) return _cachedSettings;

  const doc = await db.doc('settings/whatsapp').get();
  if (!doc.exists) throw new Error('settings/whatsapp not found in Firestore.');

  const data = doc.data();

  // Ensure fromNumber has + prefix (E.164 format required by Exotel)
  const rawFrom = data.mobile || '';
  const fromNumber = rawFrom.startsWith('+') ? rawFrom : `+${rawFrom}`;

  _cachedSettings = {
    apiKey:      data.apiKey     || '',
    apiToken:    data.apiToken   || '',
    accountSid:  data.accountSid || '',
    fromNumber,                          // e.g. "+919876543210"
    subdomain:   data.baseUrl    || 'api.exotel.com',
  };

  // URL format per Exotel docs:
  // https://<api_key>:<api_token>@<subdomain>/v2/accounts/<sid>/messages
// Change this in getSettings():
_cachedSettings.sendUrl =
  `https://${_cachedSettings.apiKey}:${_cachedSettings.apiToken}` +
  `@${_cachedSettings.subdomain}/v2/accounts/${_cachedSettings.accountSid}/messages`;

  console.log(`✅ Exotel settings loaded — from: ${fromNumber}, sid: ${_cachedSettings.accountSid}`);
  return _cachedSettings;
}

// ── Ensure phone is in E.164 format ───────────────────────────────────────
function toE164(phone) {
  const cleaned = (phone || '').trim();
  return cleaned.startsWith('+') ? cleaned : `+${cleaned}`;
}


// ════════════════════════════════════════════════════════════════════════════
// INBOUND WEBHOOK
// Exotel POSTs here when a customer sends a WhatsApp message.
// Set URL in: Exotel Dashboard → Messaging → Webhooks → Inbound URL
// URL: https://us-central1-paybaygo-crm-f16f6.cloudfunctions.net/exotelWebhook
// ════════════════════════════════════════════════════════════════════════════

exports.exotelWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') return res.status(405).send('Method not allowed');

  try {
    const messages = req.body?.whatsapp?.messages;
    if (!messages || messages.length === 0) return res.sendStatus(200);

    for (const msg of messages) {
      if (msg.callback_type !== 'incoming_message') continue;

      // Exotel sends "from" as "+919876543210" — keep the + for doc ID
      const phone     = msg.from;
      const name      = msg.profile_name || phone;
      const sid       = msg.sid;
      const timestamp = new Date(msg.timestamp);
      const content   = msg.content;

      let text = '';
      switch (content?.type) {
        case 'text':      text = content.text?.body || ''; break;
        case 'image':     text = content.image?.caption ? `📷 ${content.image.caption}` : '📷 Image'; break;
        case 'document':  text = content.document?.filename ? `📄 ${content.document.filename}` : '📄 Document'; break;
        case 'audio':     text = '🎵 Audio message'; break;
        case 'video':     text = '🎬 Video message'; break;
        case 'location':  text = '📍 Location shared'; break;
        case 'button':    text = content.button?.text || '🔘 Button reply'; break;
        case 'interactive':
          text = content.interactive?.list_reply?.title
              || content.interactive?.button_reply?.title
              || '💬 Interactive reply';
          break;
        default: text = `[${content?.type || 'unknown'}]`;
      }

      // Save message — doc ID = phone with + (e.g. "+919876543210")
      await db.collection('conversations').doc(phone).collection('messages').add({
        text,
        isMe:      false,
        isRead:    false,
        exotelSid: sid,
        timestamp: admin.firestore.Timestamp.fromDate(timestamp),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update conversation summary
      await db.collection('conversations').doc(phone).set({
        phone,
        name,
        lastMessage: text,
        lastTime:    admin.firestore.FieldValue.serverTimestamp(),
        unread:      admin.firestore.FieldValue.increment(1),
      }, { merge: true });

      console.log(`📩 Inbound from ${name} (${phone}): "${text}"`);
    }

    return res.sendStatus(200);
  } catch (err) {
    console.error('Webhook error:', err);
    return res.sendStatus(200); // always 200 to prevent Exotel retries
  }
});


// ════════════════════════════════════════════════════════════════════════════
// SEND MESSAGE (Firebase callable)
// Flutter → this function → Exotel API → customer WhatsApp
// ════════════════════════════════════════════════════════════════════════════

exports.sendWhatsAppMessage = functions.https.onCall(async (data, context) => {
  const { phone: rawPhone, text } = data?.data ?? data;

  // Ensure E.164 format — Exotel docs require "+919876543210" format
  const phone = toE164(rawPhone);

  console.log(`📤 sendWhatsAppMessage — to: "${phone}", text: "${text}"`);

  if (!rawPhone || !text) {
    console.error(`❌ Missing params — rawPhone: "${rawPhone}", text: "${text}"`);
    throw new functions.https.HttpsError('invalid-argument', 'Both phone and text are required.');
  }

  const settings = await getSettings();

  // Payload per Exotel API docs — recipient_type is required
  const payload = {
    whatsapp: {
      messages: [{
        from: settings.fromNumber,  // "+919876543210" format
        to:   phone,                // "+919876543210" format
        content: {
          recepient_type: 'individual',   // ← required per docs
          type: 'text',
          text: {
            preview_url: false,
            body: text,
          },
        },
      }],
    },
  };

  console.log(`📡 Calling Exotel API: ${settings.sendUrl}`);
  console.log(`📦 Payload: ${JSON.stringify(payload)}`);

  try {
    const response = await axios.post(settings.sendUrl, payload, {
      headers: { 'Content-Type': 'application/json' },
      timeout: 15000,
    });

    console.log(`✅ Exotel response: ${JSON.stringify(response.data)}`);

    const msgResponse = response.data?.response?.whatsapp?.messages?.[0];
    const exotelSid   = msgResponse?.data?.sid || null;
    const status      = msgResponse?.status || 'unknown';

    if (status !== 'success') {
      console.warn(`⚠️ Exotel non-success status: ${JSON.stringify(msgResponse)}`);
    }

    // Save outgoing message to Firestore
    // Use the same phone (with +) as doc ID so it matches inbound conversation
    await db.collection('conversations').doc(phone).collection('messages').add({
      text,
      isMe:      true,
      isRead:    true,
      exotelSid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update conversation summary
    await db.collection('conversations').doc(phone).set({
      phone,
      lastMessage: text,
      lastTime:    admin.firestore.FieldValue.serverTimestamp(),
      unread:      0,
    }, { merge: true });

    return { success: true, sid: exotelSid, status };

  } catch (err) {
    const errDetail = err.response?.data;
    console.error(`❌ Exotel API error: ${JSON.stringify(errDetail || err.message)}`);
    throw new functions.https.HttpsError(
      'internal',
      `Exotel error: ${JSON.stringify(errDetail) || err.message}`
    );
  }
});
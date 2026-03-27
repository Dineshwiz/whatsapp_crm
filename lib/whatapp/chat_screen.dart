import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class _Contact {
  final String phone;
  final String name;
  final String lastMessage;
  final DateTime? lastTime;
  final int unread;

  const _Contact({
    required this.phone,
    required this.name,
    required this.lastMessage,
    this.lastTime,
    this.unread = 0,
  });

  /// Two-letter initials for the avatar
  String get avatar {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  factory _Contact.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return _Contact(
      phone:       doc.id,
      name:        data['name']        ?? doc.id,
      lastMessage: data['lastMessage'] ?? '',
      lastTime:    (data['lastTime'] as Timestamp?)?.toDate(),
      unread:      (data['unread']  as num?)?.toInt() ?? 0,
    );
  }
}

class _Message {
  final String id;
  final String text;
  final bool isMe;
  final DateTime? timestamp;
  final bool isRead;

  const _Message({
    required this.id,
    required this.text,
    required this.isMe,
    this.timestamp,
    this.isRead = true,
  });

  String get timeLabel {
    if (timestamp == null) return '';
    final h = timestamp!.hour.toString().padLeft(2, '0');
    final m = timestamp!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  factory _Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return _Message(
      id:        doc.id,
      text:      data['text']   ?? '',
      isMe:      data['isMe']   ?? false,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      isRead:    data['isRead'] ?? true,
    );
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _db        = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final _msgCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();

  _Contact? _selectedContact;
  String    _searchQuery = '';
  bool      _sending     = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Firestore streams ──────────────────────────────────────────────────────

  /// All conversations ordered by most recent — drives the contact list
  Stream<List<_Contact>> get _contactsStream =>
      _db
          .collection('conversations')
          .orderBy('lastTime', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map(_Contact.fromFirestore).toList());

  /// All messages in a single conversation — drives the chat area
  Stream<List<_Message>> _messagesStream(String phone) =>
      _db
          .collection('conversations')
          .doc(phone)
          .collection('messages')
          .orderBy('timestamp')
          .snapshots()
          .map((snap) => snap.docs.map(_Message.fromFirestore).toList());

  // ── Send message via Firebase callable → Exotel API ──────────────────────

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _selectedContact == null || _sending) return;

    setState(() => _sending = true);
    _msgCtrl.clear();

    try {
      // Calls the Firebase Cloud Function "sendWhatsAppMessage"
      // which internally:
      //   1. Posts to Exotel API → delivers to customer's WhatsApp
      //   2. Saves message to Firestore → chat stream updates instantly
      final callable = _functions.httpsCallable('sendWhatsAppMessage');
      await callable.call({
        'phone': _selectedContact!.phone,
        'text':  text,
      });

      _scrollToBottom();
    } on FirebaseFunctionsException catch (e) {
      _showSnackbar('Send failed: ${e.message}', isError: true);
    } catch (e) {
      _showSnackbar('Error: $e', isError: true);
    } finally {
      setState(() => _sending = false);
    }
  }

  // ── Mark conversation as read when opened ─────────────────────────────────

  Future<void> _markAsRead(String phone) async {
    try {
      await _db
          .collection('conversations')
          .doc(phone)
          .update({'unread': 0});
    } catch (_) {}
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: isError ? Colors.redAccent : const Color(0xFF2979FF),
      behavior: SnackBarBehavior.floating,
    ));
  }

  String _formatTime(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    } else {
      return '${dt.day}/${dt.month}';
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  Widget _buildDesktopLayout() => Row(children: [
    Container(
      width: 300,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: _buildContactList(),
    ),
    Expanded(
      child: _selectedContact == null
          ? _buildEmptyState()
          : _buildChatArea(_selectedContact!),
    ),
  ]);

  Widget _buildMobileLayout() {
    if (_selectedContact != null) {
      return Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(children: [
            IconButton(
              onPressed: () => setState(() => _selectedContact = null),
              icon: const Icon(Icons.arrow_back),
            ),
            _buildAvatar(_selectedContact!.avatar),
            const SizedBox(width: 10),
            Text(_selectedContact!.name,
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ]),
        ),
        Expanded(child: _buildChatArea(_selectedContact!)),
      ]);
    }
    return _buildContactList();
  }

  // ── New conversation dialog ────────────────────────────────────────────────

  void _showNewChatDialog() {
    final phoneCtrl = TextEditingController();
    final nameCtrl  = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New Conversation',
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Customer Name',
              hintText:  'e.g. Arjun Kumar',
              labelStyle: GoogleFonts.poppins(fontSize: 13),
              prefixIcon: const Icon(Icons.person_outline, size: 18),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Phone Number (with country code)',
              hintText:  'e.g. 919876543210',
              labelStyle: GoogleFonts.poppins(fontSize: 13),
              prefixIcon: const Icon(Icons.phone_outlined, size: 18),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 8),
          Text('No + or spaces. Example: 919876543210',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.grey)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final phone = phoneCtrl.text.trim();
              final name  = nameCtrl.text.trim();
              if (phone.isEmpty) return;
              Navigator.of(ctx).pop();
              setState(() {
                _selectedContact = _Contact(
                  phone:       phone,
                  name:        name.isNotEmpty ? name : phone,
                  lastMessage: '',
                );
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2979FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Start Chat',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Contact list ───────────────────────────────────────────────────────────

  Widget _buildContactList() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Chats',
                  style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E))),
              InkWell(
                onTap: _showNewChatDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2979FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.add, size: 15,
                        color: Color(0xFF2979FF)),
                    const SizedBox(width: 4),
                    Text('New Chat',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2979FF))),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(
                hintText:  'Search contacts...',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ]),
      ),
      const Divider(height: 1, color: Color(0xFFF0F0F0)),
      Expanded(
        child: StreamBuilder<List<_Contact>>(
          stream: _contactsStream,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF2979FF)),
              );
            }
            if (snap.hasError) {
              return Center(
                child: Text('Error loading chats',
                    style: GoogleFonts.poppins(color: Colors.grey)),
              );
            }

            final contacts = (snap.data ?? []).where((c) {
              if (_searchQuery.isEmpty) return true;
              return c.name.toLowerCase().contains(_searchQuery.toLowerCase())
                  || c.phone.contains(_searchQuery);
            }).toList();

            if (contacts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.chat_bubble_outline,
                        size: 40, color: Color(0xFFB0BEC5)),
                    const SizedBox(height: 12),
                    Text('No conversations yet',
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text('Messages will appear here automatically',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (_, i) => _buildContactTile(contacts[i]),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildContactTile(_Contact contact) {
    final isSelected = _selectedContact?.phone == contact.phone;
    return InkWell(
      onTap: () {
        setState(() => _selectedContact = contact);
        if (contact.unread > 0) _markAsRead(contact.phone);
      },
      child: Container(
        color: isSelected ? const Color(0xFFE3F2FD) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          _buildAvatar(contact.avatar),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(contact.name,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A2E))),
                  if (contact.lastTime != null)
                    Text(_formatTime(contact.lastTime!),
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      contact.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  if (contact.unread > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 18, height: 18,
                      decoration: const BoxDecoration(
                          color: Color(0xFF2979FF), shape: BoxShape.circle),
                      child: Center(
                        child: Text('${contact.unread}',
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Chat area ──────────────────────────────────────────────────────────────

  Widget _buildChatArea(_Contact contact) {
    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: Row(children: [
          _buildAvatar(contact.avatar),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(contact.name,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A2E))),
            Text(contact.phone,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey)),
          ]),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: Colors.grey),
          ),
        ]),
      ),

      // Messages — live Firestore stream
      Expanded(
        child: StreamBuilder<List<_Message>>(
          stream: _messagesStream(contact.phone),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF2979FF)),
              );
            }
            if (snap.hasError) {
              return Center(
                child: Text('Error loading messages',
                    style: GoogleFonts.poppins(color: Colors.grey)),
              );
            }

            final messages = snap.data ?? [];

            // Scroll to bottom on new message
            if (messages.isNotEmpty) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _scrollToBottom());
            }

            if (messages.isEmpty) {
              return Center(
                child: Text('No messages yet. Start the conversation!',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.grey)),
              );
            }

            return Container(
              color: const Color(0xFFF5F6FA),
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                itemCount: messages.length,
                itemBuilder: (_, i) => _buildMessageBubble(messages[i]),
              ),
            );
          },
        ),
      ),

      // Input bar
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: Row(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _msgCtrl,
                style: GoogleFonts.poppins(fontSize: 14),
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle:
                  GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sending ? null : _sendMessage,
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _sending
                    ? const Color(0xFF2979FF).withOpacity(0.5)
                    : const Color(0xFF2979FF),
                shape: BoxShape.circle,
              ),
              child: _sending
                  ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
                  : const Icon(Icons.send_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ]),
      ),
    ]);
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Widget _buildMessageBubble(_Message msg) {
    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.55),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.isMe ? const Color(0xFF2979FF) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(16),
            topRight:    const Radius.circular(16),
            bottomLeft:  Radius.circular(msg.isMe ? 16 : 4),
            bottomRight: Radius.circular(msg.isMe ? 4 : 16),
          ),
          boxShadow: const [BoxShadow(
              color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment:
          msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(msg.text,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: msg.isMe
                        ? Colors.white
                        : const Color(0xFF1A1A2E))),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(msg.timeLabel,
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: msg.isMe ? Colors.white70 : Colors.grey)),
              if (msg.isMe) ...[
                const SizedBox(width: 4),
                Icon(Icons.done_all,
                    size: 12,
                    color: msg.isRead ? Colors.white : Colors.white54),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(36),
          ),
          child: const Icon(Icons.chat_outlined,
              size: 34, color: Color(0xFF2979FF)),
        ),
        const SizedBox(height: 16),
        Text('Select a conversation',
            style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A2E))),
        const SizedBox(height: 6),
        Text('Choose a contact to start chatting.',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
      ]),
    );
  }

  Widget _buildAvatar(String initials) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFF2979FF).withOpacity(0.12),
      child: Text(initials,
          style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2979FF))),
    );
  }
}
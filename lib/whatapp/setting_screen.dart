import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WhatsAppSettingsScreen extends StatefulWidget {
  const WhatsAppSettingsScreen({super.key});

  @override
  State<WhatsAppSettingsScreen> createState() => _WhatsAppSettingsScreenState();
}

class _WhatsAppSettingsScreenState extends State<WhatsAppSettingsScreen> {
  // Firestore reference
  final _db = FirebaseFirestore.instance;
  static const _docPath = 'settings/whatsapp'; // collection: settings, doc: whatsapp

  // State
  bool _loading = true;
  bool _saving   = false;
  bool _editMode = false;

  // Visibility toggles
  bool _apiKeyVisible = false;
  bool _tokenVisible  = false;
  bool _wabaIdVisible = false;

  // Data holders
  Map<String, String> _data = {
    'provider'  : '',
    'baseUrl'   : '',
    'mobile'    : '',
    'apiKey'    : '',
    'apiToken'  : '',
    'wabaId'    : '',
    'accountSid': '',    // ← ADD THIS
    'status'    : 'Connected',
  };

  // Edit controllers
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _initControllers();
    _fetchSettings();
  }

  void _initControllers() {
    for (final key in _data.keys) {
      _controllers[key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── FIRESTORE: GET ────────────────────────────────────────────────────────
  Future<void> _fetchSettings() async {
    try {
      final doc = await _db.doc(_docPath).get();

      if (doc.exists && doc.data() != null) {
        final fetched = Map<String, String>.from(
          doc.data()!.map((k, v) => MapEntry(k, v.toString())),
        );
        setState(() {
          _data = {..._data, ...fetched};
          _syncControllers();
          _loading = false;
        });
      } else {
        // Document doesn't exist yet — save defaults
        await _saveSettings(showSnackbar: false);
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
      _showSnackbar('Failed to load settings: $e', isError: true);
    }
  }

  // ─── FIRESTORE: UPDATE ─────────────────────────────────────────────────────
  Future<void> _saveSettings({bool showSnackbar = true}) async {
    setState(() => _saving = true);
    try {
      // Read from controllers if in edit mode
      final updatedData = {
        for (final key in _data.keys)
          key: _controllers[key]!.text.isNotEmpty
              ? _controllers[key]!.text
              : _data[key]!,
      };

      await _db.doc(_docPath).set(updatedData, SetOptions(merge: true));

      setState(() {
        _data    = updatedData;
        _editMode = false;
        _saving  = false;
      });

      if (showSnackbar) _showSnackbar('Settings saved successfully ✓');
    } catch (e) {
      setState(() => _saving = false);
      _showSnackbar('Failed to save: $e', isError: true);
    }
  }

  void _syncControllers() {
    for (final key in _data.keys) {
      _controllers[key]!.text = _data[key] ?? '';
    }
  }

  void _enterEditMode() {
    _syncControllers();
    setState(() => _editMode = true);
  }

  void _cancelEdit() {
    _syncControllers();
    setState(() => _editMode = false);
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────────
  void _copyToClipboard(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    _showSnackbar('$label copied');
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF2979FF),
      ),
    );
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F6FA),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF2979FF))),
      );
    }

    final isConnected = _data['status']?.toLowerCase() == 'connected';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WhatsApp Settings',
                        style: GoogleFonts.poppins(
                            fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
                    const SizedBox(height: 4),
                    Text('View your connected WhatsApp Business account details.',
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
                  ],
                ),
                // Edit / Save / Cancel buttons
                if (!_editMode)
                  _actionButton(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    onTap: _enterEditMode,
                    color: const Color(0xFF2979FF),
                  )
                else
                  Row(
                    children: [
                      _actionButton(
                        label: 'Cancel',
                        icon: Icons.close,
                        onTap: _cancelEdit,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      _actionButton(
                        label: _saving ? 'Saving…' : 'Save',
                        icon: Icons.save_outlined,
                        onTap: _saving ? null : () => _saveSettings(),
                        color: const Color(0xFF43A047),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Status banner ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isConnected ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isConnected ? const Color(0xFF81C784) : const Color(0xFFEF9A9A),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isConnected ? Icons.check_circle : Icons.error_outline,
                    color: isConnected ? const Color(0xFF43A047) : Colors.redAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Account is ${_data['status']} and ready to use.',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: isConnected ? const Color(0xFF2E7D32) : Colors.redAccent,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Account Information Card ────────────────────────────────────
            _buildCard(
              title: 'Account Information',
              icon: Icons.business_outlined,
              children: [
                _buildRow(
                  label: 'Provider',
                  fieldKey: 'provider',
                  canCopy: false,
                  canToggle: false,
                ),
                _buildRow(
                  label: 'Base URL',
                  fieldKey: 'baseUrl',
                  canCopy: true,
                  canToggle: false,
                ),
                _buildRow(
                  label: 'Mobile Number',
                  fieldKey: 'mobile',
                  canCopy: true,
                  canToggle: false,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Credentials Card ────────────────────────────────────────────
            _buildCard(
              title: 'Credentials',
              icon: Icons.vpn_key_outlined,
              children: [
                _buildRow(
                  label: 'API Key',
                  fieldKey: 'apiKey',
                  canCopy: true,
                  canToggle: true,
                  isVisible: _apiKeyVisible,
                  onToggle: () => setState(() => _apiKeyVisible = !_apiKeyVisible),
                ),
                _buildRow(
                  label: 'API Token',
                  fieldKey: 'apiToken',
                  canCopy: true,
                  canToggle: true,
                  isVisible: _tokenVisible,
                  onToggle: () => setState(() => _tokenVisible = !_tokenVisible),
                ),
                _buildRow(
                  label: 'WABA ID',
                  fieldKey: 'wabaId',
                  canCopy: true,
                  canToggle: true,
                  isVisible: _wabaIdVisible,
                  onToggle: () => setState(() => _wabaIdVisible = !_wabaIdVisible),
                ),
                _buildRow(
                  label: 'Account SID',
                  fieldKey: 'accountSid',
                  canCopy: true,
                  canToggle: false,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Danger zone: refresh from Firestore ─────────────────────────
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  setState(() => _loading = true);
                  await _fetchSettings();
                },
                icon: const Icon(Icons.refresh, size: 16, color: Colors.grey),
                label: Text('Refresh from cloud',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── CARD WRAPPER ──────────────────────────────────────────────────────────
  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF2979FF)),
                const SizedBox(width: 8),
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          ...children,
        ],
      ),
    );
  }

  // ─── ROW: view mode shows value, edit mode shows TextField ────────────────
  Widget _buildRow({
    required String label,
    required String fieldKey,
    required bool canCopy,
    required bool canToggle,
    bool isVisible = true,
    VoidCallback? onToggle,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final rawValue    = _data[fieldKey] ?? '';
    final displayValue = canToggle && !isVisible ? '•' * 20 : rawValue;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
              ),
              Expanded(
                child: _editMode
                    ? TextField(
                  controller: _controllers[fieldKey],
                  keyboardType: keyboardType,
                  obscureText: canToggle && !isVisible,
                  style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1A1A2E)),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2979FF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                      const BorderSide(color: Color(0xFF2979FF), width: 1.5),
                    ),
                  ),
                )
                    : Text(
                  displayValue,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF1A1A2E),
                    fontWeight: FontWeight.w500,
                    letterSpacing: canToggle && !isVisible ? 2 : 0,
                  ),
                ),
              ),
              if (canToggle)
                InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 17,
                      color: Colors.grey,
                    ),
                  ),
                ),
              if (canCopy && !_editMode) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _copyToClipboard(rawValue, label),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.copy_outlined, size: 17, color: Colors.grey),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(
            height: 1, thickness: 1, color: Color(0xFFF5F5F5), indent: 20, endIndent: 20),
      ],
    );
  }

  // ─── ACTION BUTTON ─────────────────────────────────────────────────────────
  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
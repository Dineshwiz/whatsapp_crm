import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paybaygo_crm/Home/profile_controller.dart';
import '../routes.dart';
import '../whatapp/chat_screen.dart';
import '../whatapp/setting_screen.dart';
import '../whatapp/template.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class _MenuItem {
  final String label;
  final IconData icon;
  final bool hasArrow;
  const _MenuItem(
      {required this.label, required this.icon, this.hasArrow = false});
}

class _SectionMenu {
  final String title;
  final List<_MenuItem> items;
  const _SectionMenu({required this.title, required this.items});
}

// ─── Data ─────────────────────────────────────────────────────────────────────

final List<_MenuItem> _mainItems = [
  _MenuItem(label: 'Dashboard', icon: Icons.dashboard_outlined),
];

final List<_SectionMenu> _sections = [
  _SectionMenu(title: 'WhatsApp', items: [
    _MenuItem(
        label: 'WhatsApp Settings',
        icon: Icons.settings_outlined,
        hasArrow: true),
    _MenuItem(
        label: 'Chat Screen', icon: Icons.chat_outlined, hasArrow: true),
    _MenuItem(
        label: 'Template',
        icon: Icons.description_outlined,
        hasArrow: true),
  ]),
];

final List<_MenuItem> _bottomItems = [
  _MenuItem(label: 'Support', icon: Icons.headset_mic_outlined),
  //_MenuItem(label: 'Settings', icon: Icons.settings_outlined),
  _MenuItem(label: 'Logout', icon: Icons.power_settings_new_outlined),
];

// ─── Profile Dialog ───────────────────────────────────────────────────────────

class _ProfileDialog extends StatefulWidget {
  final UserController userController;
  const _ProfileDialog({required this.userController});

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _phoneCtrl;

  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    final u = widget.userController;
    _firstNameCtrl = TextEditingController(text: u.firstName);
    _lastNameCtrl  = TextEditingController(text: u.lastName);
    _emailCtrl     = TextEditingController(text: u.email);
    _usernameCtrl  = TextEditingController(text: u.userName);
    _phoneCtrl     = TextEditingController(text: u.phone);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      final docId = widget.userController.docId;
      if (docId.isEmpty) throw Exception('Document ID not found.');

      final newUsername = _usernameCtrl.text.trim();

      // ✅ 1. Check if username already exists (excluding current user)
      final query = await _db
          .collection('login')
          .where('user_name', isEqualTo: newUsername)
          .get();

      final isUsernameTaken = query.docs.any((doc) => doc.id != docId);

      if (isUsernameTaken) {
        setState(() => _isSaving = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Username is already taken',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return; // ⛔ STOP update
      }

      // ✅ 2. Proceed with update
      final updatedData = {
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'user_name': newUsername,
        'phone_number': _phoneCtrl.text.trim(),
      };

      await _db.collection('login').doc(docId).update(updatedData);

      // Update local state
      final current = Map<String, dynamic>.from(
          widget.userController.userData.value);
      current.addAll(updatedData);
      widget.userController.setUser(current);

      setState(() {
        _isEditing = false;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully',
              style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: const Color(0xFF2E7D52),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}',
              style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  letterSpacing: 0.4)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            readOnly: readOnly || !_isEditing,
            keyboardType: keyboardType,
            style: GoogleFonts.poppins(
                fontSize: 14, color: const Color(0xFF1A1A2E)),
            decoration: InputDecoration(
              filled: true,
              fillColor: readOnly
                  ? const Color(0xFFF5F5F5)
                  : (_isEditing
                  ? Colors.white
                  : const Color(0xFFF5F6FA)),

              // ✅ Leading icon with background
              prefixIcon: Container(
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2979FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFF2979FF)),
              ),

              contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: readOnly
                      ? Colors.grey.shade200
                      : (_isEditing
                      ? const Color(0xFF2979FF).withOpacity(0.5)
                      : Colors.grey.shade200),
                  width: 1,
                ),
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                const BorderSide(color: Color(0xFF2979FF), width: 1.5),
              ),

              suffixIcon: readOnly
                  ? const Icon(Icons.lock_outline,
                  size: 16, color: Colors.grey)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.userController;

    return Dialog(
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding:
      const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        width: 420,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF2979FF),
                borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  // Avatar circle with initials
                  Obx(() => CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    child: Text(
                      u.firstName.isNotEmpty
                          ? u.firstName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  )),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Obx(() => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.fullName,
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                        Text(u.userRole.toUpperCase(),
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.white70,
                                letterSpacing: 0.5)),
                      ],
                    )),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close,
                        color: Colors.white70, size: 20),
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            label: 'First Name',
                            controller: _firstNameCtrl,
                            icon: Icons.person_outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            label: 'Last Name',
                            controller: _lastNameCtrl,
                            icon: Icons.person_2_outlined,
                          ),
                        ),
                      ],
                    ),

                    _buildField(
                      label: 'Email',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      icon: Icons.email_outlined,
                    ),

                    _buildField(
                      label: 'Username',
                      controller: _usernameCtrl,
                      icon: Icons.alternate_email,
                    ),

                    _buildField(
                      label: 'Phone Number',
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      icon: Icons.phone_outlined,
                    ),

                    _buildField(
                      label: 'User Role',
                      controller: TextEditingController(text: u.userRole),
                      readOnly: true,
                      icon: Icons.admin_panel_settings_outlined,
                    ),
                  ],
                ),
              ),
            ),

            // ── Footer buttons ──────────────────────────────────────────
            Padding(
              padding:
              const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_isEditing) ...[
                    // Cancel
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                        // Reset controllers to original values
                        _firstNameCtrl.text = u.firstName;
                        _lastNameCtrl.text  = u.lastName;
                        _emailCtrl.text     = u.email;
                        _usernameCtrl.text  = u.userName;
                        _phoneCtrl.text     = u.phone;
                        setState(() => _isEditing = false);
                      },
                      child: Text('Cancel',
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: Colors.grey)),
                    ),
                    const SizedBox(width: 8),
                    // Save
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2979FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 10),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                          : Text('Save Changes',
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                  ] else ...[
                    // Edit button
                    ElevatedButton.icon(
                      onPressed: () =>
                          setState(() => _isEditing = true),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text('Edit Profile',
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2979FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dashboard Screen ─────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedLabel = 'Dashboard';

  // Access the already-registered controller
// AFTER — registers it if not already registered
  final _userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout',
            style: GoogleFonts.poppins(
                fontSize: 17, fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to logout?',
            style:
            GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700])),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _userController.clearUser(); // ✅ clear user data
              Get.offAllNamed(AppRoutes.login); // ✅ go back to login
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Logout',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Profile dialog ────────────────────────────────────────────────────────

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (_) => _ProfileDialog(userController: _userController),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    switch (_selectedLabel) {
      case 'WhatsApp Settings':
        return const WhatsAppSettingsScreen();
      case 'Chat Screen':
        return const ChatScreen();
      case 'Template':
        return const TemplateScreen();
      default:
        return Center(
          child: Text(_selectedLabel,
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A2E))),
        );
    }
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(bool isMobile) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Builder(
        builder: (ctx) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 8,
                  offset: Offset(0, 2))
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (isMobile)
                    IconButton(
                      onPressed: () =>
                          Scaffold.of(ctx).openDrawer(),
                      icon: const Icon(Icons.menu,
                          color: Color(0xFF1A1A2E)),
                    ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: const Color(0xFF2979FF),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.local_parking_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Text('PayBayGo Admin',
                      style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A2E))),
                  const SizedBox(width: 24),
                  Container(
                    height: 36,
                    width: 200,
                    decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(20)),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF1A1A2E)),
                      decoration: InputDecoration(
                        hintText: 'Search',
                        hintStyle: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search,
                            size: 18, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding:
                        const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Notification bell
                  Stack(
                    children: [
                      IconButton(
                          onPressed: () {},
                          icon: const Icon(
                              Icons.notifications_outlined,
                              color: Color(0xFF1A1A2E),
                              size: 24)),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                              color: Color(0xFF2979FF),
                              shape: BoxShape.circle),
                          child: Center(
                            child: Text('2',
                                style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),

                  // ✅ User avatar — tappable, shows real name
                  InkWell(
                    onTap: _showProfileDialog,
                    child: Obx(() => Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                          const Color(0xFF2979FF),
                          child: Text(
                            _userController.firstName.isNotEmpty
                                ? _userController.firstName[0]
                                .toUpperCase()
                                : '?',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userController.fullName.isNotEmpty
                                  ? _userController.fullName
                                  : 'User',
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color:
                                  const Color(0xFF1A1A2E)),
                            ),
                            Text(
                              _userController.userRole
                                  .isNotEmpty
                                  ? _userController.userRole
                                  .substring(0, 1)
                                  .toUpperCase() +
                                  _userController.userRole
                                      .substring(1)
                                  : '',
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down,
                            size: 18, color: Colors.grey),
                      ],
                    )),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Sidebar ───────────────────────────────────────────────────────────────

  Widget _buildSidebarContent() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ..._mainItems.map((item) => _buildTile(item)),
                const SizedBox(height: 4),
                ..._sections.map((section) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding:
                      const EdgeInsets.fromLTRB(16, 14, 16, 2),
                      child: Text(section.title,
                          style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                              letterSpacing: 0.3)),
                    ),
                    ...section.items
                        .map((item) => _buildTile(item)),
                  ],
                )),
              ],
            ),
          ),
          const Divider(
              height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
                children: _bottomItems
                    .map((item) =>
                    _buildTile(item, isBottom: true))
                    .toList()),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(_MenuItem item, {bool isBottom = false}) {
    final bool isSelected = _selectedLabel == item.label;

    return InkWell(
      onTap: () {
        // ✅ Handle logout separately
        if (item.label == 'Logout') {
          _handleLogout();
          return;
        }
        setState(() => _selectedLabel = item.label);
        if (MediaQuery.of(context).size.width < 768) {
          Navigator.of(context).maybePop();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2979FF)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          dense: true,
          leading: Icon(item.icon,
              size: 19,
              color: isSelected
                  ? Colors.white
                  : (isBottom
                  ? (item.label == 'Logout'
                  ? const Color(0xFFE53935) // red for logout
                  : Colors.grey)
                  : const Color(0xFF444444))),
          title: Text(item.label,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: isSelected
                      ? Colors.white
                      : (item.label == 'Logout'
                      ? const Color(0xFFE53935) // red for logout
                      : (isBottom
                      ? Colors.grey
                      : const Color(0xFF1A1A2E))))),
          trailing: item.hasArrow && !isSelected
              ? const Icon(Icons.chevron_right,
              size: 16, color: Colors.grey)
              : null,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12),
          minLeadingWidth: 20,
          visualDensity: const VisualDensity(vertical: -1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      drawer: isMobile ? _buildSidebarContent() : null,
      appBar: _buildAppBar(isMobile),
      body: isMobile
          ? _buildBody()
          : Row(
        children: [
          SizedBox(
              width: 230, child: _buildSidebarContent()),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}
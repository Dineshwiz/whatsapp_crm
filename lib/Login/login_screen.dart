import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../Home/profile_controller.dart';
import '../routes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Top-toast widget (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _TopToast extends StatefulWidget {
  final String title;
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const _TopToast({
    required this.title,
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _progressAnim;

  static const _duration = Duration(milliseconds: 3000);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: _duration);

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.14, curve: Curves.easeOutBack),
    ));

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.10, curve: Curves.easeIn),
      ),
    );

    _progressAnim = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.10, 1.0, curve: Curves.linear),
      ),
    );

    _controller.forward();
    Future.delayed(_duration, () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() async {
    await _controller.animateTo(0,
        duration: const Duration(milliseconds: 280), curve: Curves.easeIn);
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isError = widget.isError;
    final accent =
    isError ? const Color(0xFFE53935) : const Color(0xFF2E7D52);
    final bgColor =
    isError ? const Color(0xFF2C1212) : const Color(0xFF122C1E);
    final borderColor = isError
        ? const Color(0xFFB71C1C).withOpacity(0.7)
        : const Color(0xFF1B5E38).withOpacity(0.7);
    final titleColor =
    isError ? const Color(0xFFEF9A9A) : const Color(0xFF80CBC4);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.only(top: 1),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: accent, width: 1.5),
                            ),
                            child: Icon(
                              isError
                                  ? Icons.close_rounded
                                  : Icons.check_rounded,
                              color: accent,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.title,
                                    style: GoogleFonts.poppins(
                                        color: titleColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(widget.message,
                                    style: GoogleFonts.poppins(
                                        color: Colors.white60,
                                        fontSize: 12.5,
                                        height: 1.4)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _dismiss,
                            child: const Icon(Icons.close,
                                color: Colors.white38, size: 18),
                          ),
                        ],
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _progressAnim,
                      builder: (_, __) => LinearProgressIndicator(
                        value: _progressAnim.value,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                        minHeight: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Login screen
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  final _db = FirebaseFirestore.instance;

  // Ensure UserController is registered
  final _userController = Get.put(UserController());

  OverlayEntry? _toastEntry;

  void _showTopToast(String title, String message, {bool isError = false}) {
    _toastEntry?.remove();
    _toastEntry = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TopToast(
        title: title,
        message: message,
        isError: isError,
        onDismiss: () {
          entry.remove();
          _toastEntry = null;
        },
      ),
    );

    _toastEntry = entry;
    Overlay.of(context).insert(entry);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showTopToast('Missing fields',
          'Please enter username and password.',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final querySnapshot = await _db
          .collection('login')
          .where('user_name', isEqualTo: username)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        _showTopToast('Login failed', 'Invalid username or password.',
            isError: true);
        setState(() => _isLoading = false);
        return;
      }

      final doc  = querySnapshot.docs.first;
      final data = doc.data();
      final storedPassword = data['password']?.toString() ?? '';

      if (password == storedPassword) {
        // ✅ Store user data (include doc_id for later edits)
        _userController.setUser({...data, 'doc_id': doc.id});

        _showTopToast(
          'Welcome back 👋',
          '${data['first_name'] ?? username} ${data['last_name'] ?? ''}',
          isError: false,
        );
        await Future.delayed(const Duration(milliseconds: 800));
        Get.offAllNamed(AppRoutes.dashboard);
      } else {
        _showTopToast('Login failed', 'Invalid username or password.',
            isError: true);
      }
    } catch (e) {
      _showTopToast('Error', e.toString(), isError: true);
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset(
            'assets/images/tow_truck.jpeg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1a2a4a), Color(0xFF0d1b2e)],
                  ),
                ),
              );
            },
          ),

          // Dark overlay
          Container(color: const Color(0xFF0d1b2e).withOpacity(0.65)),

          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.local_parking_rounded,
                                color: Colors.white, size: 48),
                          ),

                          const SizedBox(height: 20),

                          Text(
                            'PARK SAFE WITH PAYBAYGO',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 40),

                          _buildTextField(
                            controller: _usernameController,
                            label: 'Username',
                            icon: Icons.person_outline,
                          ),

                          const SizedBox(height: 16),

                          _buildTextField(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock_outline,
                            obscureText: _obscurePassword,

                            // ✅ Press Enter → Login
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _handleLogin(),

                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.white60,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),

                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (value) => setState(
                                          () => _rememberMe = value ?? false),
                                  checkColor: Colors.white,
                                  fillColor:
                                  WidgetStateProperty.resolveWith((states) =>
                                  states.contains(WidgetState.selected)
                                      ? const Color(0xFF2979FF)
                                      : Colors.transparent),
                                  side: const BorderSide(
                                      color: Colors.white54, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text('Remember me',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white70, fontSize: 15)),
                            ],
                          ),

                          const SizedBox(height: 28),

                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2979FF),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                const Color(0xFF2979FF).withOpacity(0.6),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5),
                              )
                                  : Text('Login',
                                  style: GoogleFonts.poppins(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5)),
                            ),
                          ),

                          const SizedBox(height: 20),

                          GestureDetector(
                            onTap: () => debugPrint('Forgot password tapped'),
                            child: Text(
                              'Forgot Password ?',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 14,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    // ✅ Add these
    TextInputAction? textInputAction,
    Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      obscureText: obscureText,
      style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
        GoogleFonts.poppins(color: Colors.white60, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white54, size: 22),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Colors.white.withOpacity(0.25), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: Colors.white, width: 1.5),
        ),
        contentPadding:
        const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      ),
    );
  }
}
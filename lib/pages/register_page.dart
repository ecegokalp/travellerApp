import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late AnimationController _contentController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  int _currentImageIndex = 0;
  Timer? _imageTimer;

  static const _sunset = Color(0xFFFF6B6B);
  static const _sunsetDark = Color(0xFFE85D5D);
  static const _orange = Color(0xFFFF8E53);
  static const _deepBlue = Color(0xFF1A1D26);
  static const _white = Color(0xFFFFFFFF);

  static const _images = [
    'https://images.unsplash.com/photo-1516483638261-f4dbaf036963?w=1200&q=85', // Italy coast
    'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=1200&q=85', // Tropical beach
    'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=1200&q=85', // Mountain lake
    'https://images.unsplash.com/photo-1539037116277-4db20889f2d4?w=1200&q=85', // Northern lights
  ];

  @override
  void initState() {
    super.initState();
    _contentController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: const Interval(0.1, 0.6, curve: Curves.easeOut)),
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _contentController, curve: const Interval(0.15, 0.7, curve: Curves.easeOutCubic)),
    );
    _contentController.forward();
    _imageTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => _currentImageIndex = (_currentImageIndex + 1) % _images.length);
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _contentController.dispose();
    _imageTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authService.signUp(
        email: _emailController.text.trim(), password: _passwordController.text.trim(),
        fullName: _fullNameController.text.trim(), username: _usernameController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        'email-already-in-use' => 'An account already exists with this email.',
        'weak-password' => 'Password is too weak. Use at least 6 characters.',
        'invalid-email' => 'Please enter a valid email address.',
        _ => 'Registration failed. Please try again.',
      };
      _showSnackBar(msg, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('An unexpected error occurred.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: _white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: GoogleFonts.inter(color: _white, fontSize: 14))),
      ]),
      backgroundColor: isError ? _sunsetDark : const Color(0xFF2ECC71),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  InputDecoration _inputDeco({required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: _white.withAlpha(100), fontSize: 15),
      prefixIcon: Padding(padding: const EdgeInsets.only(left: 14, right: 10), child: Icon(icon, color: _white.withAlpha(140), size: 20)),
      prefixIconConstraints: const BoxConstraints(minWidth: 48),
      suffixIcon: suffix,
      filled: true, fillColor: _white.withAlpha(18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _white.withAlpha(40), width: 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _sunset, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    );
  }

  Widget _passSuffix(bool obscure, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.only(right: 14), child: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _white.withAlpha(150), size: 20)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D26),
      body: Stack(
        children: [
          // Full-screen background
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 1200),
              child: SizedBox.expand(
                key: ValueKey(_images[_currentImageIndex]),
                child: CachedNetworkImage(
                  imageUrl: _images[_currentImageIndex],
                  fit: BoxFit.cover,
                  placeholder: (_, p1) => Container(color: _deepBlue),
                  errorWidget: (_, e1, e2) => Container(color: _deepBlue),
                ),
              ),
            ),
          ),

          // Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withAlpha(80), Colors.black.withAlpha(40), Colors.black.withAlpha(100), Colors.black.withAlpha(160)],
                  stops: const [0.0, 0.25, 0.6, 1.0],
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: FadeTransition(
                        opacity: _fadeIn,
                        child: SlideTransition(
                          position: _slideUp,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Top
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: _white.withAlpha(20),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: _white.withAlpha(40)),
                                        ),
                                        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _white),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text('Join Wander', style: GoogleFonts.playfairDisplay(fontSize: 40, fontWeight: FontWeight.w700, color: _white, letterSpacing: 0.5)),
                                    const SizedBox(height: 8),
                                    Text('Create your account and\nstart exploring.', style: GoogleFonts.inter(fontSize: 15, color: _white.withAlpha(180), height: 1.5)),
                                  ],
                                ),
                              ),

                              // Bottom: form + sign in link
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                        child: Container(
                                          padding: const EdgeInsets.all(24),
                                          decoration: BoxDecoration(
                                            color: _white.withAlpha(30),
                                            borderRadius: BorderRadius.circular(24),
                                            border: Border.all(color: _white.withAlpha(40), width: 1),
                                          ),
                                          child: Form(
                                            key: _formKey,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                TextFormField(
                                                  controller: _fullNameController, textCapitalization: TextCapitalization.words,
                                                  style: GoogleFonts.inter(color: _white, fontSize: 15, fontWeight: FontWeight.w500),
                                                  decoration: _inputDeco(hint: 'Full Name', icon: Icons.person_outline_rounded),
                                                  validator: (v) {
                                                    if (v == null || v.trim().isEmpty) return 'Please enter your full name';
                                                    if (v.trim().length < 2) return 'Name must be at least 2 characters';
                                                    return null;
                                                  },
                                                ),
                                                const SizedBox(height: 12),

                                                TextFormField(
                                                  controller: _usernameController,
                                                  style: GoogleFonts.inter(color: _white, fontSize: 15, fontWeight: FontWeight.w500),
                                                  decoration: _inputDeco(hint: 'Username', icon: Icons.alternate_email_rounded),
                                                  validator: (v) {
                                                    if (v == null || v.trim().isEmpty) return 'Please choose a username';
                                                    if (v.trim().length < 3) return 'Username must be at least 3 characters';
                                                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) return 'Only letters, numbers, and underscores';
                                                    return null;
                                                  },
                                                ),
                                                const SizedBox(height: 12),

                                                TextFormField(
                                                  controller: _emailController, keyboardType: TextInputType.emailAddress,
                                                  style: GoogleFonts.inter(color: _white, fontSize: 15, fontWeight: FontWeight.w500),
                                                  decoration: _inputDeco(hint: 'Email address', icon: Icons.email_outlined),
                                                  validator: (v) {
                                                    if (v == null || v.trim().isEmpty) return 'Please enter your email';
                                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) return 'Please enter a valid email';
                                                    return null;
                                                  },
                                                ),
                                                const SizedBox(height: 12),

                                                TextFormField(
                                                  controller: _passwordController, obscureText: _obscurePassword,
                                                  style: GoogleFonts.inter(color: _white, fontSize: 15, fontWeight: FontWeight.w500),
                                                  decoration: _inputDeco(hint: 'Password', icon: Icons.lock_outline_rounded, suffix: _passSuffix(_obscurePassword, () => setState(() => _obscurePassword = !_obscurePassword))),
                                                  validator: (v) {
                                                    if (v == null || v.trim().isEmpty) return 'Please enter a password';
                                                    if (v.length < 6) return 'Password must be at least 6 characters';
                                                    return null;
                                                  },
                                                ),
                                                const SizedBox(height: 12),

                                                TextFormField(
                                                  controller: _confirmPasswordController, obscureText: _obscureConfirm,
                                                  style: GoogleFonts.inter(color: _white, fontSize: 15, fontWeight: FontWeight.w500),
                                                  decoration: _inputDeco(hint: 'Confirm Password', icon: Icons.lock_outline_rounded, suffix: _passSuffix(_obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm))),
                                                  validator: (v) {
                                                    if (v == null || v.trim().isEmpty) return 'Please confirm your password';
                                                    if (v != _passwordController.text) return 'Passwords do not match';
                                                    return null;
                                                  },
                                                ),
                                                const SizedBox(height: 24),

                                                Container(
                                                  decoration: BoxDecoration(
                                                    gradient: const LinearGradient(colors: [_orange, _sunset]),
                                                    borderRadius: BorderRadius.circular(14),
                                                    boxShadow: [BoxShadow(color: _orange.withAlpha(60), blurRadius: 16, offset: const Offset(0, 6))],
                                                  ),
                                                  child: ElevatedButton(
                                                    onPressed: _isLoading ? null : _handleRegister,
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.transparent, shadowColor: Colors.transparent, foregroundColor: _white,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                      minimumSize: const Size(double.infinity, 54), elevation: 0,
                                                    ),
                                                    child: _isLoading
                                                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: _white))
                                                        : Text('Create Account', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 20),

                                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Text('Already have an account?  ', style: GoogleFonts.inter(color: _white.withAlpha(160), fontSize: 14)),
                                      GestureDetector(
                                        onTap: () => Navigator.pop(context),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: _white.withAlpha(20),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: _white.withAlpha(40)),
                                          ),
                                          child: Text('Sign In', style: GoogleFonts.inter(color: _white, fontSize: 14, fontWeight: FontWeight.w700)),
                                        ),
                                      ),
                                    ]),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

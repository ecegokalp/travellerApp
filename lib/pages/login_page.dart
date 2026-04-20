import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

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
  static const _subtleText = Color(0xFF9CA3AF);


  static const _destinations = [
    _Destination(
      image: 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=1200&q=85',
      city: 'Paris',
      country: 'France',
    ),
    _Destination(
      image: 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=1200&q=85',
      city: 'Bali',
      country: 'Indonesia',
    ),
    _Destination(
      image: 'https://images.unsplash.com/photo-1526392060635-9d6019884377?w=1200&q=85',
      city: 'Machu Picchu',
      country: 'Peru',
    ),
    _Destination(
      image: 'https://images.unsplash.com/photo-1555400038-63f5ba517a47?w=1200&q=85',
      city: 'Santorini',
      country: 'Greece',
    ),
    _Destination(
      image: 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=1200&q=85',
      city: 'Kyoto',
      country: 'Japan',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: const Interval(0.1, 0.6, curve: Curves.easeOut)),
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _contentController, curve: const Interval(0.15, 0.7, curve: Curves.easeOutCubic)),
    );
    _contentController.forward();

    _imageTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => _currentImageIndex = (_currentImageIndex + 1) % _destinations.length);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _contentController.dispose();
    _imageTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authService.signIn(email: _emailController.text.trim(), password: _passwordController.text.trim());
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        'user-not-found' => 'No account found with this email.',
        'wrong-password' => 'Incorrect password. Please try again.',
        'invalid-email' => 'Please enter a valid email address.',
        'user-disabled' => 'This account has been disabled.',
        'invalid-credential' => 'Invalid email or password.',
        _ => 'Login failed. Please try again.',
      };
      _showSnackBar(msg, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('An unexpected error occurred.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      await _authService.signInWithGoogle();
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Google sign-in failed. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmail = TextEditingController(text: _emailController.text.trim());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool sending = false;
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 40),
              decoration: const BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 32),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F0),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.lock_reset_rounded, size: 36, color: _sunset),
                ),
                const SizedBox(height: 24),
                Text('Reset Password', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w700, color: _deepBlue)),
                const SizedBox(height: 12),
                Text(
                  'Enter your email address and we\'ll send you\na link to reset your password.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: _subtleText, fontSize: 14, height: 1.6),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: resetEmail,
                  keyboardType: TextInputType.emailAddress,
                  cursorColor: _sunset,
                  style: GoogleFonts.inter(color: _deepBlue, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFFBFC5D2), fontSize: 15),
                    prefixIcon: const Padding(padding: EdgeInsets.only(left: 14, right: 10), child: Icon(Icons.email_outlined, color: _subtleText, size: 20)),
                    prefixIconConstraints: const BoxConstraints(minWidth: 48),
                    filled: true, fillColor: const Color(0xFFF8F9FB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _sunset, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 54,
                  child: _gradientBtn(
                    onPressed: sending ? null : () async {
                      final email = resetEmail.text.trim();
                      if (email.isEmpty) return;
                      setSheet(() => sending = true);
                      try {
                        await _authService.sendPasswordResetEmail(email);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _showSnackBar('If an account exists for $email, a reset link has been sent.');
                      } on FirebaseAuthException catch (e) {
                        if (!ctx.mounted) return;
                        if (e.code == 'invalid-email') {
                          setSheet(() => sending = false);
                          _showSnackBar('Please enter a valid email address.', isError: true);
                        } else {
                          Navigator.pop(ctx);
                          _showSnackBar('If an account exists for $email, a reset link has been sent.');
                        }
                      } catch (_) {
                        if (!ctx.mounted) return;
                        setSheet(() => sending = false);
                      }
                    },
                    loading: sending, label: 'Send Reset Link',
                  ),
                ),
              ]),
            ),
          );
        });
      },
    );
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
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 10),
        child: Icon(icon, color: _white.withAlpha(140), size: 20),
      ),
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

  Widget _gradientBtn({required VoidCallback? onPressed, required bool loading, required String label}) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_sunset, _orange]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: _sunset.withAlpha(60), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, shadowColor: Colors.transparent, foregroundColor: _white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minimumSize: const Size(double.infinity, 54), elevation: 0,
        ),
        child: loading
            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: _white))
            : Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final dest = _destinations[_currentImageIndex];

    return Scaffold(
      backgroundColor: _deepBlue,
      body: Stack(
        children: [
          // Full-screen background image
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 1200),
              child: SizedBox.expand(
                key: ValueKey(dest.image),
                child: CachedNetworkImage(
                  imageUrl: dest.image,
                  fit: BoxFit.cover,
                  placeholder: (_, p1) => Container(color: _deepBlue),
                  errorWidget: (_, e1, e2) => Container(color: _deepBlue),
                ),
              ),
            ),
          ),

          // Full-screen dark overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(80),
                    Colors.black.withAlpha(40),
                    Colors.black.withAlpha(100),
                    Colors.black.withAlpha(160),
                  ],
                  stops: const [0.0, 0.25, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // Content - fills entire screen
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
                              // Top: Brand
                              Padding(
                                padding: EdgeInsets.only(top: screenH * 0.06),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Wander',
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 48, fontWeight: FontWeight.w700, color: _white, letterSpacing: 1, height: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Discover the world,\none journey at a time.',
                                      style: GoogleFonts.inter(fontSize: 16, color: _white.withAlpha(190), height: 1.5, fontWeight: FontWeight.w400),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(children: [
                                      const Icon(Icons.location_on, color: _sunset, size: 15),
                                      const SizedBox(width: 4),
                                      Text('${dest.city}, ${dest.country}', style: GoogleFonts.inter(color: _white.withAlpha(170), fontSize: 13, fontWeight: FontWeight.w500)),
                                      const SizedBox(width: 14),
                                      ...List.generate(_destinations.length, (i) => AnimatedContainer(
                                        duration: const Duration(milliseconds: 400),
                                        margin: const EdgeInsets.only(right: 5),
                                        width: i == _currentImageIndex ? 18 : 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(3),
                                          color: i == _currentImageIndex ? _sunset : _white.withAlpha(70),
                                        ),
                                      )),
                                    ]),
                                  ],
                                ),
                              ),

                              // Bottom: Glass form card + sign up
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
                                                Text('Welcome Back', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: _white)),
                                                const SizedBox(height: 4),
                                                Text('Sign in to continue your adventure', style: GoogleFonts.inter(fontSize: 13, color: _white.withAlpha(160), height: 1.4)),
                                                const SizedBox(height: 24),

                                                TextFormField(
                                                  controller: _emailController,
                                                  keyboardType: TextInputType.emailAddress,
                                                  style: GoogleFonts.inter(color: _white, fontSize: 15, fontWeight: FontWeight.w500),
                                                  decoration: _inputDeco(hint: 'Email address', icon: Icons.email_outlined),
                                                  validator: (v) {
                                                    if (v == null || v.trim().isEmpty) return 'Please enter your email';
                                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) return 'Please enter a valid email';
                                                    return null;
                                                  },
                                                ),
                                                const SizedBox(height: 14),

                                                TextFormField(
                                                  controller: _passwordController,
                                                  obscureText: _obscurePassword,
                                                  style: GoogleFonts.inter(color: _white, fontSize: 15, fontWeight: FontWeight.w500),
                                                  decoration: _inputDeco(
                                                    hint: 'Password',
                                                    icon: Icons.lock_outline_rounded,
                                                    suffix: GestureDetector(
                                                      onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                                      child: Padding(
                                                        padding: const EdgeInsets.only(right: 14),
                                                        child: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _white.withAlpha(150), size: 20),
                                                      ),
                                                    ),
                                                  ),
                                                  validator: (v) {
                                                    if (v == null || v.trim().isEmpty) return 'Please enter your password';
                                                    if (v.length < 6) return 'Password must be at least 6 characters';
                                                    return null;
                                                  },
                                                ),
                                                const SizedBox(height: 12),

                                                Align(
                                                  alignment: Alignment.centerRight,
                                                  child: GestureDetector(
                                                    onTap: _showForgotPasswordDialog,
                                                    child: Text('Forgot password?', style: GoogleFonts.inter(color: _sunset, fontSize: 13, fontWeight: FontWeight.w600)),
                                                  ),
                                                ),
                                                const SizedBox(height: 20),

                                                _gradientBtn(onPressed: _isLoading ? null : _handleLogin, loading: _isLoading, label: 'Sign In'),
                                                const SizedBox(height: 20),

                                                Row(children: [
                                                  Expanded(child: Container(height: 0.5, color: _white.withAlpha(50))),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                                    child: Text('or', style: GoogleFonts.inter(color: _white.withAlpha(120), fontSize: 13, fontWeight: FontWeight.w500)),
                                                  ),
                                                  Expanded(child: Container(height: 0.5, color: _white.withAlpha(50))),
                                                ]),
                                                const SizedBox(height: 20),

                                                SizedBox(
                                                  height: 52,
                                                  child: OutlinedButton(
                                                    onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                                                    style: OutlinedButton.styleFrom(
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                      side: BorderSide(color: _white.withAlpha(50), width: 1),
                                                      backgroundColor: _white.withAlpha(15),
                                                    ),
                                                    child: _isGoogleLoading
                                                        ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _white.withAlpha(150)))
                                                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                                            Image.network(
                                                              'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                                                              height: 20, width: 20,
                                                              errorBuilder: (_, e1, e2) => const Icon(Icons.g_mobiledata_rounded, size: 26, color: _white),
                                                            ),
                                                            const SizedBox(width: 12),
                                                            Text('Continue with Google', style: GoogleFonts.inter(color: _white, fontSize: 15, fontWeight: FontWeight.w600)),
                                                          ]),
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
                                      Text("Don't have an account?  ", style: GoogleFonts.inter(color: _white.withAlpha(160), fontSize: 14)),
                                      GestureDetector(
                                        onTap: () => Navigator.push(context, PageRouteBuilder(
                                          pageBuilder: (c, a, _) => const RegisterPage(),
                                          transitionsBuilder: (c, a, _, child) => FadeTransition(opacity: a, child: child),
                                          transitionDuration: const Duration(milliseconds: 350),
                                        )),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: _white.withAlpha(20),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: _white.withAlpha(40)),
                                          ),
                                          child: Text('Sign Up', style: GoogleFonts.inter(color: _white, fontSize: 14, fontWeight: FontWeight.w700)),
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

class _Destination {
  final String image;
  final String city;
  final String country;
  const _Destination({required this.image, required this.city, required this.country});
}

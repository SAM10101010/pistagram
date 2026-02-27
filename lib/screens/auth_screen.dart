import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/account_manager_service.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';
import 'otp_screen.dart';
import 'forgot_password_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool isAddAccount;
  const AuthScreen({super.key, this.isAddAccount = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _accountManager = AccountManagerService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _googleLoading = false;
  bool _obscurePassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeIn));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _navigateAfterAuth() async {
    final profileComplete = await _authService.isProfileComplete();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              profileComplete ? const HomeScreen() : const ProfileSetupScreen(),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // P5: Resolve username to email if input doesn't contain @
        String loginEmail = _emailController.text.trim();
        if (!loginEmail.contains('@')) {
          final resolved = await _authService.resolveUsernameToEmail(loginEmail);
          if (resolved == null) {
            throw Exception('Username not found');
          }
          loginEmail = resolved;
        }

        final cred = await _authService.login(
          email: loginEmail,
          password: _passwordController.text.trim(),
        );

        // Save account for multi-account switching
        final uid = cred.user?.uid ?? '';
        if (uid.isNotEmpty) {
          await _accountManager.saveAccount(
            uid: uid,
            email: loginEmail,
            password: _passwordController.text.trim(),
          );
          // Update display info from profile
          _accountManager.updateAccountInfo(uid);
        }

        // If adding account, just pop back to account switcher
        if (widget.isAddAccount) {
          if (mounted) Navigator.pop(context);
          return;
        }

        // P6: OTP verification on login
        final profileComplete = await _authService.isProfileComplete();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OtpScreen(
                email: loginEmail,
                nextScreen: profileComplete ? const HomeScreen() : const ProfileSetupScreen(),
              ),
            ),
          );
        }
      } else {
        await _authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // Navigate to OTP verification after signup
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OtpScreen(
                email: _emailController.text.trim(),
                nextScreen: const ProfileSetupScreen(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains(']')) msg = msg.split(']').last.trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    HapticFeedback.lightImpact();
    setState(() => _googleLoading = true);
    try {
      final cred = await _authService.signInWithGoogle();

      // Save account for multi-account switching
      final uid = cred.user?.uid ?? '';
      final email = cred.user?.email ?? '';
      if (uid.isNotEmpty && email.isNotEmpty) {
        // Store with a generated token so switchAccount can re-auth via Google
        await _accountManager.saveAccount(
          uid: uid,
          email: email,
          password: '__google__',
          displayName: cred.user?.displayName ?? '',
          profilePicUrl: cred.user?.photoURL ?? '',
        );
        _accountManager.updateAccountInfo(uid);
      }

      // If adding account, just pop back to account switcher
      if (widget.isAddAccount) {
        if (mounted) Navigator.pop(context);
        return;
      }

      await _navigateAfterAuth();
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains(']')) msg = msg.split(']').last.trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF0D0D0D), Color(0xFF1A1A2E)]
                : const [Color(0xFFF8F9FA), Color(0xFFE8F4FD)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo with glow
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Pistagram',
                        style: GoogleFonts.outfit(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [
                                Color(0xFFF58529),
                                Color(0xFFDD2A7B),
                                Color(0xFF8134AF),
                              ],
                            ).createShader(const Rect.fromLTWH(0, 0, 200, 40)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLogin ? 'Welcome back!' : 'Create your account',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Google Sign In Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _googleLoading ? null : _signInWithGoogle,
                          icon: _googleLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: accent,
                                  ),
                                )
                              : Image.network(
                                  'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                                  width: 22,
                                  height: 22,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.g_mobiledata,
                                    size: 28,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                          label: Text(
                            'Continue with Google',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white.withAlpha(8) : Colors.white,
                            side: BorderSide(
                              color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(15),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Divider
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Email or Username field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: _isLogin ? TextInputType.text : TextInputType.emailAddress,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: _inputDecoration(
                          _isLogin ? 'Email or Username' : 'Email',
                          _isLogin ? Icons.person_outline : Icons.email_outlined,
                          isDark,
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return _isLogin ? 'Enter your email or username' : 'Enter your email';
                          }
                          // Only validate email format for signup
                          if (!_isLogin && !val.contains('@')) return 'Invalid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration:
                            _inputDecoration(
                              'Password',
                              Icons.lock_outline,
                              isDark,
                            ).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Enter your password';
                          }
                          if (val.length < 6) return 'Min 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Forgot password link (only in login mode)
                      if (_isLogin)
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                              );
                            },
                            child: Text(
                              'Forgot Password?',
                              style: GoogleFonts.inter(
                                color: accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              colors: [
                                accent,
                                HSLColor.fromColor(accent)
                                    .withHue(
                                      (HSLColor.fromColor(accent).hue + 40) %
                                          360,
                                    )
                                    .toColor(),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withAlpha(77),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    _isLogin ? 'Log In' : 'Sign Up',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Toggle login/signup
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isLogin
                                ? "Don't have an account? "
                                : 'Already have an account? ',
                            style: GoogleFonts.inter(
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _isLogin = !_isLogin);
                            },
                            child: Text(
                              _isLogin ? 'Sign Up' : 'Log In',
                              style: GoogleFonts.inter(
                                color: accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
      prefixIcon: Icon(icon, color: isDark ? Colors.white38 : Colors.black38),
      filled: true,
      fillColor: isDark
          ? Colors.white.withAlpha(15)
          : Colors.black.withAlpha(10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/email_service.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final Widget nextScreen;

  const OtpScreen({super.key, required this.email, required this.nextScreen});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final EmailService _emailService = EmailService();
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _sending = true;
  bool _verifying = false;
  bool _canResend = false;
  int _resendCountdown = 30;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _sending = true;
      _errorText = null;
      _canResend = false;
      _resendCountdown = 30;
    });

    try {
      await _emailService.sendOtp(widget.email);
      if (mounted) {
        setState(() => _sending = false);
        _startResendTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _errorText = 'Failed to send OTP. Check your connection.';
          _canResend = true;
        });
      }
    }
  }

  void _startResendTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCountdown--);
      if (_resendCountdown <= 0) {
        setState(() => _canResend = true);
        return false;
      }
      return true;
    });
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Auto-verify when all 6 digits are entered
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length == 6) {
      _verifyOtp(otp);
    }
  }

  Future<void> _verifyOtp(String otp) async {
    setState(() {
      _verifying = true;
      _errorText = null;
    });

    // Small delay for UX feedback
    await Future.delayed(const Duration(milliseconds: 300));

    if (_emailService.verifyOtp(otp)) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => widget.nextScreen),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _verifying = false;
          _errorText = 'Invalid or expired code. Try again.';
        });
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D0D)
          : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Header
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withAlpha(15),
                  boxShadow: [
                    BoxShadow(color: accent.withAlpha(30), blurRadius: 24, spreadRadius: 4),
                    BoxShadow(color: accent.withAlpha(15), blurRadius: 40, spreadRadius: 8),
                  ],
                ),
                child: Icon(Icons.mark_email_read_rounded, size: 44, color: accent),
              ),
              const SizedBox(height: 20),
              Text(
                'Verify Your Email',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to',
                style: GoogleFonts.inter(fontSize: 14, color: subColor),
              ),
              const SizedBox(height: 4),
              Text(
                widget.email,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
              const SizedBox(height: 36),

              // OTP input boxes
              if (_sending)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        color: accent,
                        strokeWidth: 2.5,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sending verification code...',
                        style: GoogleFonts.inter(color: subColor, fontSize: 13),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    return SizedBox(
                      width: 48,
                      height: 56,
                      child: TextField(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        enabled: !_verifying,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          counterText: '',
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
                            borderSide: BorderSide(color: accent, width: 2),
                          ),
                        ),
                        onChanged: (val) => _onDigitChanged(i, val),
                      ),
                    );
                  }),
                ),

              if (_verifying)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: accent,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Verifying...',
                        style: GoogleFonts.inter(color: subColor, fontSize: 13),
                      ),
                    ],
                  ),
                ),

              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _errorText!,
                    style: GoogleFonts.inter(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              const Spacer(),

              // Resend section
              if (!_sending)
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    children: [
                      Text(
                        "Didn't receive the code?",
                        style: GoogleFonts.inter(color: subColor, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _canResend ? _sendOtp : null,
                        child: Text(
                          _canResend
                              ? 'Resend Code'
                              : 'Resend in ${_resendCountdown}s',
                          style: GoogleFonts.inter(
                            color: _canResend ? accent : subColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

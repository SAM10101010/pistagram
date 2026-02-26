import 'dart:math';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  static const String _senderEmail = 'study.samagg@gmail.com';
  static const String _appPassword = 'wxox flre bqyk jdta';

  final SmtpServer _smtpServer = gmail(_senderEmail, _appPassword);

  String _currentOtp = '';
  DateTime? _otpExpiry;

  /// Generate a 6-digit OTP and send it to the given email
  Future<String> sendOtp(String toEmail) async {
    _currentOtp = _generateOtp();
    _otpExpiry = DateTime.now().add(const Duration(minutes: 5));

    final message = Message()
      ..from = const Address(_senderEmail, 'Pistagram')
      ..recipients.add(toEmail)
      ..subject = 'Pistagram - Email Verification Code'
      ..html =
          '''
        <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px;">
          <div style="text-align: center; margin-bottom: 24px;">
            <h1 style="background: linear-gradient(135deg, #F58529, #DD2A7B, #8134AF); -webkit-background-clip: text; -webkit-text-fill-color: transparent; font-size: 28px; margin: 0;">Pistagram</h1>
          </div>
          <div style="background: #f8f9fa; border-radius: 16px; padding: 32px; text-align: center;">
            <h2 style="color: #1a1a2e; margin-top: 0;">Verify Your Email</h2>
            <p style="color: #666; font-size: 14px;">Use the code below to verify your email address. This code expires in 5 minutes.</p>
            <div style="background: #1a1a2e; color: #FFD700; font-size: 32px; font-weight: bold; letter-spacing: 8px; padding: 16px 24px; border-radius: 12px; display: inline-block; margin: 16px 0;">
              $_currentOtp
            </div>
            <p style="color: #999; font-size: 12px; margin-top: 20px;">If you didn't request this code, you can safely ignore this email.</p>
          </div>
        </div>
      ''';

    await send(message, _smtpServer);
    return _currentOtp;
  }

  /// Verify the OTP entered by the user
  bool verifyOtp(String enteredOtp) {
    if (_otpExpiry == null || DateTime.now().isAfter(_otpExpiry!)) {
      return false;
    }
    return _currentOtp == enteredOtp.trim();
  }

  /// Generate a random 6-digit OTP
  String _generateOtp() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }
}

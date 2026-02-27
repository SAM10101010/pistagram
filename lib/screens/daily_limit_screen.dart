import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/animations.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class DailyLimitScreen extends StatefulWidget {
  const DailyLimitScreen({super.key});

  @override
  State<DailyLimitScreen> createState() => _DailyLimitScreenState();
}

class _DailyLimitScreenState extends State<DailyLimitScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();

  int _todayEarned = 0;
  int _lockedPoints = 0;
  static const int _dailyCap = 100;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = _auth.currentUser?.uid ?? '';
      final userFuture = _firestore.getUser(uid);
      final txnFuture = _firestore.getUserTransactions(uid);
      final results = await Future.wait([userFuture, txnFuture]);
      final user = results[0] as dynamic;
      final transactions = results[1] as List;
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      int earned = 0;
      for (final t in transactions) {
        if (t.createdAt.isAfter(todayStart) && t.type == 'earned') {
          earned += (t.amount as num).toInt();
        }
      }

      if (mounted) {
        setState(() {
          _todayEarned = earned;
          _lockedPoints = user?.lockedPoints ?? 0;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading daily limit: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final progress = (_todayEarned / _dailyCap).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D0D)
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Daily Limit',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const ShimmerLoading(width: 180, height: 180, isCircle: true),
                  const SizedBox(height: 32),
                  const ShimmerLoading(width: 200, height: 20, borderRadius: 8),
                  const SizedBox(height: 12),
                  const ShimmerLoading(width: 280, height: 14, borderRadius: 6),
                  const SizedBox(height: 32),
                  ShimmerLoading(
                    width: double.infinity,
                    height: 160,
                    borderRadius: 14,
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Circular progress
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (progress >= 1.0 ? Colors.redAccent : accent)
                              .withAlpha(30),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 180,
                          height: 180,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 12,
                            backgroundColor: subColor.withAlpha(40),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 1.0 ? Colors.redAccent : accent,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_todayEarned',
                              style: GoogleFonts.outfit(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              'of $_dailyCap pts',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: subColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Status text
                  Text(
                    _todayEarned >= _dailyCap
                        ? 'Daily limit reached!'
                        : 'Keep watching to earn more!',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _todayEarned >= _dailyCap
                        ? 'Come back tomorrow to earn more points.'
                        : 'You can earn ${_dailyCap - _todayEarned} more points today.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: subColor,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Info cards
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withAlpha(10)
                            : Colors.black.withAlpha(10),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withAlpha(8),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How it works',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _infoRow(
                          Icons.play_circle_outline,
                          'Watch complete reels to earn points',
                          textColor,
                          subColor,
                        ),
                        const SizedBox(height: 10),
                        _infoRow(
                          Icons.stars_rounded,
                          'Earn 1-5 points per reel watched',
                          textColor,
                          subColor,
                        ),
                        const SizedBox(height: 10),
                        _infoRow(
                          Icons.schedule,
                          'Daily cap resets at midnight',
                          textColor,
                          subColor,
                        ),
                        const SizedBox(height: 10),
                        _infoRow(
                          Icons.shield_outlined,
                          'Cap prevents abuse and keeps it fair',
                          textColor,
                          subColor,
                        ),
                        if (_lockedPoints > 0) ...[
                          const SizedBox(height: 10),
                          _infoRow(
                            Icons.lock_clock_rounded,
                            'Earned points are locked for 24h before becoming available',
                            textColor,
                            subColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_lockedPoints > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withAlpha(60),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFFD700).withAlpha(25),
                            ),
                            child: const Icon(
                              Icons.lock_clock_rounded,
                              color: Color(0xFFFFD700),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$_lockedPoints pts locked',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  'Will unlock tomorrow at midnight',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: subColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color textColor, Color subColor) {
    return Row(
      children: [
        Icon(icon, size: 20, color: subColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(fontSize: 13, color: subColor),
          ),
        ),
      ],
    );
  }
}

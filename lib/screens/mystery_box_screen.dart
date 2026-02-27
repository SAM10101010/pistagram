import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/mystery_box_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/animations.dart';

class MysteryBoxScreen extends StatefulWidget {
  const MysteryBoxScreen({super.key});

  @override
  State<MysteryBoxScreen> createState() => _MysteryBoxScreenState();
}

class _MysteryBoxScreenState extends State<MysteryBoxScreen>
    with SingleTickerProviderStateMixin {
  final MysteryBoxService _mysteryBoxService = MysteryBoxService();
  final AuthService _auth = AuthService();
  final FirestoreService _firestore = FirestoreService();

  int _balance = 0;
  bool _canOpen = false;
  bool _loading = true;
  bool _opening = false;
  bool _showResult = false;
  Map<String, dynamic>? _result;
  List<Map<String, dynamic>> _history = [];

  late AnimationController _boxController;
  late Animation<double> _boxShake;

  @override
  void initState() {
    super.initState();
    _boxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _boxShake = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _boxController, curve: Curves.elasticOut),
    );
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = _auth.currentUser?.uid ?? '';
    final user = await _firestore.getUser(uid);
    _balance = user?.pointsBalance ?? 0;
    _canOpen = await _mysteryBoxService.canOpenBox(uid);
    _history = await _mysteryBoxService.getHistory(uid);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openBox() async {
    if (_opening || !_canOpen) return;
    setState(() => _opening = true);

    // Shake animation
    _boxController.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 500));

    final uid = _auth.currentUser?.uid ?? '';
    _result = await _mysteryBoxService.openBox(uid);

    if (_result != null) {
      setState(() {
        _showResult = true;
        _opening = false;
        _balance -= MysteryBoxService.boxCost;
      });
      await _loadData();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to open box. Try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _opening = false);
      }
    }
  }

  @override
  void dispose() {
    _boxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D0D)
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
        ),
        title: Text(
          'Mystery Box',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: accent, strokeWidth: 2),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Box card
                FadeInSlide(
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        colors: [const Color(0xFF9C27B0), accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9C27B0).withAlpha(50),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (_showResult && _result != null) ...[
                          // Result reveal
                          const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _result!['rewardLabel'] ?? 'Mystery Reward!',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '+${_result!['rewardValue'] ?? 0} points',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => setState(() {
                              _showResult = false;
                              _result = null;
                            }),
                            child: Text(
                              'Open another',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 14,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ] else ...[
                          // Box to open
                          AnimatedBuilder(
                            animation: _boxShake,
                            builder: (_, child) {
                              return Transform.rotate(
                                angle: sin(_boxShake.value * pi * 4) * 0.05,
                                child: child,
                              );
                            },
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white.withAlpha(20),
                                border: Border.all(
                                  color: Colors.white.withAlpha(40),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.card_giftcard_rounded,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Mystery Box',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Spend ${MysteryBoxService.boxCost} points for a random reward!',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: (_canOpen && !_opening)
                                  ? _openBox
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF9C27B0),
                                disabledBackgroundColor: Colors.white.withAlpha(
                                  50,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: _opening
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _canOpen
                                          ? 'Open Box (${MysteryBoxService.boxCost} pts)'
                                          : 'Cannot open right now',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Balance & limit info
                FadeInSlide(
                  delay: 100,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withAlpha(10)
                                  : Colors.black.withAlpha(10),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '$_balance',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                'Balance',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: subColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withAlpha(10)
                                  : Colors.black.withAlpha(10),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${MysteryBoxService.maxBoxesPerDay}/day',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                'Limit',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: subColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Reward probabilities
                FadeInSlide(
                  delay: 150,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withAlpha(10)
                            : Colors.black.withAlpha(10),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Possible Rewards',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildRewardTier(
                          '5 points',
                          '40%',
                          Colors.grey,
                          subColor,
                        ),
                        _buildRewardTier(
                          '15 points',
                          '25%',
                          Colors.blue,
                          subColor,
                        ),
                        _buildRewardTier(
                          '30 points',
                          '15%',
                          Colors.green,
                          subColor,
                        ),
                        _buildRewardTier(
                          '75 points',
                          '10%',
                          Colors.purple,
                          subColor,
                        ),
                        _buildRewardTier(
                          '150 points',
                          '5%',
                          Colors.orange,
                          subColor,
                        ),
                        _buildRewardTier(
                          'Special reward',
                          '5%',
                          const Color(0xFFFFD700),
                          subColor,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // History
                if (_history.isNotEmpty) ...[
                  Text(
                    'Recent Opens',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(_history.length.clamp(0, 10), (i) {
                    final item = _history[i];
                    final createdAt =
                        (item['createdAt'] as dynamic)?.toDate() ??
                        DateTime.now();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.card_giftcard_rounded,
                            color: accent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item['rewardLabel'] ?? 'Mystery Reward',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                                color: textColor,
                              ),
                            ),
                          ),
                          Text(
                            '+${item['rewardValue'] ?? 0} pts',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeago.format(createdAt),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: subColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
    );
  }

  Widget _buildRewardTier(
    String label,
    String chance,
    Color color,
    Color subColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(chance, style: GoogleFonts.inter(fontSize: 12, color: subColor)),
        ],
      ),
    );
  }
}

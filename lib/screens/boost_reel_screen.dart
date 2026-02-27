import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/boost_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/animations.dart';

class BoostReelScreen extends StatefulWidget {
  final String reelId;
  const BoostReelScreen({super.key, required this.reelId});

  @override
  State<BoostReelScreen> createState() => _BoostReelScreenState();
}

class _BoostReelScreenState extends State<BoostReelScreen> {
  final BoostService _boostService = BoostService();
  final AuthService _auth = AuthService();
  final FirestoreService _firestore = FirestoreService();

  int _selectedLevel = 1;
  int _balance = 0;
  bool _loading = true;
  bool _boosting = false;
  bool _alreadyBoosted = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = _auth.currentUser?.uid ?? '';
    final user = await _firestore.getUser(uid);
    _balance = user?.pointsBalance ?? 0;
    _alreadyBoosted = await _boostService.isReelBoosted(widget.reelId);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _boostReel() async {
    if (_boosting) return;
    final pricing = BoostService.boostPricing[_selectedLevel]!;
    final cost = pricing['points'] as int;

    if (_balance < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough points!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _boosting = true);
    final uid = _auth.currentUser?.uid ?? '';
    final success = await _boostService.boostReel(
      uid,
      widget.reelId,
      _selectedLevel,
    );
    if (success && mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reel boosted! ${pricing['label']} active for ${pricing['hours']}h',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to boost reel'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _boosting = false);
    }
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
          'Boost Reel',
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
          : _alreadyBoosted
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.rocket_launch_rounded, size: 48, color: accent),
                  const SizedBox(height: 12),
                  Text(
                    'This reel is already boosted!',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'Wait for the current boost to expire.',
                    style: GoogleFonts.inter(color: subColor, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Balance
                FadeInSlide(
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
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFFD700).withAlpha(30),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Color(0xFFFFD700),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Balance',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: subColor,
                              ),
                            ),
                            Text(
                              '$_balance points',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Select Boost Level',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),

                // Boost tiers
                ...BoostService.boostPricing.entries.map((entry) {
                  final level = entry.key;
                  final data = entry.value;
                  final cost = data['points'] as int;
                  final hours = data['hours'] as int;
                  final label = data['label'] as String;
                  final isSelected = _selectedLevel == level;
                  final canAfford = _balance >= cost;

                  Color tierColor;
                  IconData tierIcon;
                  switch (level) {
                    case 1:
                      tierColor = Colors.blue;
                      tierIcon = Icons.bolt_rounded;
                      break;
                    case 2:
                      tierColor = Colors.purple;
                      tierIcon = Icons.flash_on_rounded;
                      break;
                    default:
                      tierColor = const Color(0xFFFFD700);
                      tierIcon = Icons.rocket_launch_rounded;
                  }

                  return FadeInSlide(
                    delay: level * 80,
                    child: GestureDetector(
                      onTap: canAfford
                          ? () => setState(() => _selectedLevel = level)
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? tierColor.withAlpha(15)
                              : cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? tierColor
                                : (isDark
                                      ? Colors.white.withAlpha(10)
                                      : Colors.black.withAlpha(10)),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: tierColor.withAlpha(25),
                              ),
                              child: Icon(tierIcon, color: tierColor, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: canAfford ? textColor : subColor,
                                    ),
                                  ),
                                  Text(
                                    '${hours}h visibility boost',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: subColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$cost pts',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: canAfford ? tierColor : subColor,
                                  ),
                                ),
                                if (!canAfford)
                                  Text(
                                    'Not enough',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),

                // Boost button
                FadeInSlide(
                  delay: 300,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _boosting ? null : _boostReel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 4,
                      ),
                      child: _boosting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Boost for ${BoostService.boostPricing[_selectedLevel]!['points']} Points',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Info
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: accent.withAlpha(10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 20, color: accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Boosted reels get priority placement in the For You feed during the boost period.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: subColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

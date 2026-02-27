import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'my_redemptions_screen.dart';

class RedemptionSuccessScreen extends StatefulWidget {
  final String rewardTitle;
  final int pointsSpent;

  const RedemptionSuccessScreen({
    super.key,
    required this.rewardTitle,
    required this.pointsSpent,
  });

  @override
  State<RedemptionSuccessScreen> createState() => _RedemptionSuccessScreenState();
}

class _RedemptionSuccessScreenState extends State<RedemptionSuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Colors.green, Colors.green.withAlpha(180)]),
                      boxShadow: [
                        BoxShadow(color: Colors.green.withAlpha(80), blurRadius: 24, spreadRadius: 4),
                        BoxShadow(color: Colors.green.withAlpha(40), blurRadius: 40, spreadRadius: 8),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded, size: 64, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Redeemed!',
                  style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.rewardTitle,
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.pointsSpent} points spent',
                  style: GoogleFonts.inter(fontSize: 15, color: subColor),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(colors: [accent, HSLColor.fromColor(accent).withHue((HSLColor.fromColor(accent).hue + 40) % 360).toColor()]),
                      boxShadow: [BoxShadow(color: accent.withAlpha(60), blurRadius: 16, offset: const Offset(0, 4))],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const MyRedemptionsScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('View My Redemptions', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  child: Text('Back to Store', style: GoogleFonts.inter(fontSize: 15, color: subColor)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

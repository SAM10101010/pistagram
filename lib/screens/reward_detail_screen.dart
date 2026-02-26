import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/reward_model.dart';
import '../services/auth_service.dart';
import '../services/points_service.dart';
import 'redemption_success_screen.dart';

class RewardDetailScreen extends StatefulWidget {
  final RewardModel reward;
  const RewardDetailScreen({super.key, required this.reward});

  @override
  State<RewardDetailScreen> createState() => _RewardDetailScreenState();
}

class _RewardDetailScreenState extends State<RewardDetailScreen> {
  final _auth = AuthService();
  final _points = PointsService();
  bool _redeeming = false;

  Future<void> _redeem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Redeem Reward', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Spend ${widget.reward.pointsCost} points to redeem "${widget.reward.title}"?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Redeem')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _redeeming = true);
    try {
      final uid = _auth.currentUser?.uid ?? '';
      final success = await _points.redeemPoints(widget.reward.pointsCost, uid, 'Redeemed: ${widget.reward.title}');
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Not enough points!'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RedemptionSuccessScreen(
              rewardTitle: widget.reward.title,
              pointsSpent: widget.reward.pointsCost,
            ),
          ),
        );
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final reward = widget.reward;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Reward', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: textColor), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (reward.imageUrl.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: reward.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200]),
                  errorWidget: (_, __, ___) => Container(
                    color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
                    child: Icon(Icons.card_giftcard, size: 64, color: subColor),
                  ),
                ),
              )
            else
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: accent.withAlpha(30),
                  child: Icon(Icons.card_giftcard, size: 80, color: accent),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reward.title, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.stars_rounded, size: 20, color: accent),
                      const SizedBox(width: 6),
                      Text('${reward.pointsCost} points', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: accent)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (reward.description.isNotEmpty)
                    Text(reward.description, style: GoogleFonts.inter(fontSize: 15, color: textColor, height: 1.6)),
                  const SizedBox(height: 20),
                  // Info cards
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: [
                        _detailRow('Stock', reward.stock > 0 ? '${reward.stock} remaining' : 'Unlimited', textColor, subColor),
                        if (reward.expiryDate != null) ...[
                          const SizedBox(height: 12),
                          _detailRow('Expires', DateFormat('MMM d, yyyy').format(reward.expiryDate!), textColor, subColor),
                        ],
                        const SizedBox(height: 12),
                        _detailRow('Status', reward.isActive ? 'Available' : 'Unavailable', textColor, reward.isActive ? Colors.green : Colors.redAccent),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: reward.isActive
                    ? LinearGradient(colors: [accent, HSLColor.fromColor(accent).withHue((HSLColor.fromColor(accent).hue + 40) % 360).toColor()])
                    : null,
                color: reward.isActive ? null : subColor.withAlpha(40),
              ),
              child: ElevatedButton(
                onPressed: reward.isActive && !_redeeming ? _redeem : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _redeeming
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text(
                        reward.isActive ? 'Redeem for ${reward.pointsCost} pts' : 'Unavailable',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, Color textColor, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 14, color: textColor.withAlpha(150))),
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor)),
      ],
    );
  }
}

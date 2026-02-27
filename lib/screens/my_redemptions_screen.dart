import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../utils/animations.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/reward_model.dart';

class MyRedemptionsScreen extends StatefulWidget {
  const MyRedemptionsScreen({super.key});

  @override
  State<MyRedemptionsScreen> createState() => _MyRedemptionsScreenState();
}

class _MyRedemptionsScreenState extends State<MyRedemptionsScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();

  List<RedemptionModel> _redemptions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = _auth.currentUser?.uid ?? '';
      final redemptions = await _firestore.getUserRedemptions(uid);
      if (mounted) {
        setState(() {
          _redemptions = redemptions;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading redemptions: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'fulfilled':
        return Colors.green;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'fulfilled':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('My Redemptions', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: textColor), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: 5,
              itemBuilder: (_, __) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const ShimmerLoading(width: 44, height: 44, borderRadius: 12),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                    ShimmerLoading(width: 140, height: 14, borderRadius: 6),
                    SizedBox(height: 8),
                    ShimmerLoading(width: 90, height: 10, borderRadius: 6),
                  ])),
                  const ShimmerLoading(width: 60, height: 14, borderRadius: 6),
                ]),
              ),
            )
          : _redemptions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[100]),
                        child: Icon(Icons.card_giftcard_rounded, size: 36, color: subColor),
                      ),
                      const SizedBox(height: 20),
                      Text('No redemptions yet', style: GoogleFonts.inter(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('Redeem rewards from the store!', style: GoogleFonts.inter(color: subColor, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _redemptions.length,
                  itemBuilder: (ctx, i) {
                    final r = _redemptions[i];
                    final statusColor = _statusColor(r.status);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(10)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(_statusIcon(r.status), color: statusColor, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.rewardTitle, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                                const SizedBox(height: 4),
                                Text(DateFormat('MMM d, yyyy').format(r.createdAt), style: GoogleFonts.inter(fontSize: 12, color: subColor)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('-${r.pointsSpent} pts', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withAlpha(25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  r.status[0].toUpperCase() + r.status.substring(1),
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

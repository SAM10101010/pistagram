import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/moderation_service.dart';
import '../../services/fraud_service.dart';
import 'admin_user_management_screen.dart';
import 'admin_reel_moderation_screen.dart';
import 'admin_reward_management_screen.dart';
import 'admin_fraud_screen.dart';
import 'admin_analytics_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _moderation = ModerationService();
  final _fraud = FraudService();

  int _totalUsers = 0;
  int _totalReels = 0;
  int _pendingReports = 0;
  int _flaggedAccounts = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final usersSnap = await _firestore.collection('users').count().get();
      final reelsSnap = await _firestore.collection('reels').count().get();
      final reports = await _moderation.getPendingReports();
      final flags = await _fraud.getUnresolvedFlags();

      if (mounted) {
        setState(() {
          _totalUsers = usersSnap.count ?? 0;
          _totalReels = reelsSnap.count ?? 0;
          _pendingReports = reports.length;
          _flaggedAccounts = flags.length;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading admin dashboard: $e');
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Admin Panel', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: textColor), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _statCard('Users', _totalUsers, Icons.people, Colors.blue, cardColor, textColor, subColor),
                      _statCard('Reels', _totalReels, Icons.play_circle, Colors.purple, cardColor, textColor, subColor),
                      _statCard('Reports', _pendingReports, Icons.report, Colors.orange, cardColor, textColor, subColor),
                      _statCard('Flagged', _flaggedAccounts, Icons.flag, Colors.redAccent, cardColor, textColor, subColor),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Quick actions
                  Text('Management', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: subColor)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: [
                        _actionTile(Icons.people_outline, 'User Management', 'Manage users, suspensions & bans', textColor, subColor, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUserManagementScreen()));
                        }),
                        Divider(height: 1, color: subColor.withAlpha(30)),
                        _actionTile(Icons.movie_filter_outlined, 'Reel Moderation', 'Review reported reels', textColor, subColor, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReelModerationScreen()));
                        }),
                        Divider(height: 1, color: subColor.withAlpha(30)),
                        _actionTile(Icons.card_giftcard, 'Reward Management', 'Add, edit & manage rewards', textColor, subColor, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminRewardManagementScreen()));
                        }),
                        Divider(height: 1, color: subColor.withAlpha(30)),
                        _actionTile(Icons.security, 'Fraud Detection', 'Review flagged accounts', textColor, subColor, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFraudScreen()));
                        }),
                        Divider(height: 1, color: subColor.withAlpha(30)),
                        _actionTile(Icons.analytics_outlined, 'Analytics', 'Platform statistics & insights', textColor, subColor, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAnalyticsScreen()));
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statCard(String label, int count, IconData icon, Color color, Color cardColor, Color textColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const Spacer(),
              Text(_formatCount(count), style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: subColor)),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String title, String subtitle, Color textColor, Color subColor, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: subColor)),
      trailing: Icon(Icons.chevron_right, color: subColor),
      onTap: onTap,
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

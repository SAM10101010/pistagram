import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final _firestore = FirebaseFirestore.instance;

  int _totalUsers = 0;
  int _totalReels = 0;
  int _totalViews = 0;
  int _totalPointsDistributed = 0;
  List<Map<String, dynamic>> _topCreators = [];
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

      // Get total views from reels
      final reelsDocs = await _firestore.collection('reels').get();
      int totalViews = 0;
      for (final doc in reelsDocs.docs) {
        totalViews += (doc.data()['viewsCount'] as int?) ?? 0;
      }

      // Get total points distributed from transactions
      int totalPoints = 0;
      final txSnap = await _firestore.collection('transactions').where('type', isEqualTo: 'earned').get();
      for (final doc in txSnap.docs) {
        totalPoints += (doc.data()['amount'] as int?) ?? 0;
      }

      // Top creators by follower count
      final topCreatorsSnap = await _firestore.collection('users').orderBy('followersCount', descending: true).limit(10).get();
      final topCreators = topCreatorsSnap.docs.map((d) {
        final data = d.data();
        return {
          'username': data['username'] ?? '',
          'followers': data['followersCount'] ?? 0,
          'totalLikes': data['totalLikes'] ?? 0,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _totalUsers = usersSnap.count ?? 0;
          _totalReels = reelsSnap.count ?? 0;
          _totalViews = totalViews;
          _totalPointsDistributed = totalPoints;
          _topCreators = topCreators;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
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
        title: Text('Analytics', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
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
                  Text('Platform Overview', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: subColor)),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _statCard('Total Users', _totalUsers, Icons.people, Colors.blue, cardColor, textColor, subColor),
                      _statCard('Total Reels', _totalReels, Icons.play_circle, Colors.purple, cardColor, textColor, subColor),
                      _statCard('Total Views', _totalViews, Icons.visibility, Colors.teal, cardColor, textColor, subColor),
                      _statCard('Points Given', _totalPointsDistributed, Icons.stars, Colors.orange, cardColor, textColor, subColor),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Top creators
                  Text('Top Creators', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: subColor)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
                    child: _topCreators.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('No creators yet', style: GoogleFonts.inter(color: subColor)),
                          )
                        : Column(
                            children: _topCreators.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final creator = entry.value;
                              return Column(
                                children: [
                                  ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: accent.withAlpha(30),
                                      child: Text('${idx + 1}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: accent)),
                                    ),
                                    title: Text(creator['username'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                                    subtitle: Text('${_formatCount(creator['followers'] as int)} followers', style: GoogleFonts.inter(fontSize: 12, color: subColor)),
                                    trailing: Text('${_formatCount(creator['totalLikes'] as int)} likes', style: GoogleFonts.inter(fontSize: 12, color: subColor)),
                                  ),
                                  if (idx < _topCreators.length - 1) Divider(height: 1, color: subColor.withAlpha(30)),
                                ],
                              );
                            }).toList(),
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
              Text(_formatCount(count), style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: subColor)),
        ],
      ),
    );
  }
}

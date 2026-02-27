import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../utils/animations.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestore = FirestoreService();
  final AuthService _auth = AuthService();
  late TabController _tabController;

  List<Map<String, dynamic>> _weeklyData = [];
  List<Map<String, dynamic>> _monthlyData = [];
  int? _myWeeklyRank;
  int? _myMonthlyRank;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final uid = _auth.currentUser?.uid ?? '';
      final results = await Future.wait([
        _firestore.getWeeklyLeaderboard(),
        _firestore.getMonthlyLeaderboard(),
        _firestore.getUserRank(uid, 'leaderboardWeekly'),
        _firestore.getUserRank(uid, 'leaderboardMonthly'),
      ]);
      _weeklyData = results[0] as List<Map<String, dynamic>>;
      _monthlyData = results[1] as List<Map<String, dynamic>>;
      _myWeeklyRank = results[2] as int?;
      _myMonthlyRank = results[3] as int?;
    } catch (e) {
      debugPrint('Leaderboard load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

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
          'Leaderboard',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: accent.withAlpha(25),
          ),
          dividerColor: Colors.transparent,
          labelColor: accent,
          unselectedLabelColor: subColor,
          labelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
          ],
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: accent, strokeWidth: 2),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLeaderboardTab(
                  _weeklyData,
                  _myWeeklyRank,
                  accent,
                  isDark,
                  textColor,
                  subColor,
                ),
                _buildLeaderboardTab(
                  _monthlyData,
                  _myMonthlyRank,
                  accent,
                  isDark,
                  textColor,
                  subColor,
                ),
              ],
            ),
    );
  }

  Widget _buildLeaderboardTab(
    List<Map<String, dynamic>> data,
    int? myRank,
    Color accent,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.leaderboard_outlined, size: 48, color: subColor),
            const SizedBox(height: 12),
            Text(
              'Leaderboard not available yet',
              style: GoogleFonts.inter(color: subColor),
            ),
            Text(
              'Keep watching to appear here!',
              style: GoogleFonts.inter(color: subColor, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // My rank card
        if (myRank != null)
          FadeInSlide(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [accent, accent.withAlpha(180)],
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '#$myRank',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Rank',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Keep watching to climb!',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),

        // Top 3 podium
        if (data.length >= 3)
          FadeInSlide(
            delay: 100,
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withAlpha(10)
                      : Colors.black.withAlpha(10),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildPodiumItem(
                    data[1],
                    2,
                    accent,
                    isDark,
                    textColor,
                    subColor,
                    height: 80,
                  ),
                  _buildPodiumItem(
                    data[0],
                    1,
                    accent,
                    isDark,
                    textColor,
                    subColor,
                    height: 100,
                  ),
                  _buildPodiumItem(
                    data[2],
                    3,
                    accent,
                    isDark,
                    textColor,
                    subColor,
                    height: 65,
                  ),
                ],
              ),
            ),
          ),

        // Remaining list (skip top 3 if podium is shown)
        ...List.generate(data.length >= 3 ? data.length - 3 : data.length, (i) {
          final actualIndex = data.length >= 3 ? i + 3 : i;
          final entry = data[actualIndex];
          return FadeInSlide(
            delay: 150 + i * 30,
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      '#${actualIndex + 1}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: subColor,
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 18,
                    backgroundImage:
                        (entry['profilePicUrl'] as String?)?.isNotEmpty == true
                        ? CachedNetworkImageProvider(entry['profilePicUrl'])
                        : null,
                    child:
                        (entry['profilePicUrl'] as String?)?.isNotEmpty != true
                        ? Icon(Icons.person, size: 18, color: subColor)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry['username'] ?? 'User',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                        Text(
                          '${entry['completedWatches'] ?? 0} reels watched',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: subColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${entry['points'] ?? 0} pts',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPodiumItem(
    Map<String, dynamic> entry,
    int rank,
    Color accent,
    bool isDark,
    Color textColor,
    Color subColor, {
    required double height,
  }) {
    final color = _getRankColor(rank);
    return SizedBox(
      width: 80,
      child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rank == 1)
          Icon(Icons.workspace_premium_rounded, color: color, size: 28),
        const SizedBox(height: 4),
        CircleAvatar(
          radius: rank == 1 ? 30 : 24,
          backgroundColor: color.withAlpha(40),
          backgroundImage:
              (entry['profilePicUrl'] as String?)?.isNotEmpty == true
              ? CachedNetworkImageProvider(entry['profilePicUrl'])
              : null,
          child: (entry['profilePicUrl'] as String?)?.isNotEmpty != true
              ? Icon(Icons.person, size: rank == 1 ? 28 : 22, color: color)
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          entry['username'] ?? 'User',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: textColor,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        Text(
          '${entry['completedWatches'] ?? 0}',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 60,
          height: height * 0.5,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: color,
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.grey;
    }
  }
}

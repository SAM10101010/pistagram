import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/achievement_service.dart';
import '../services/auth_service.dart';
import '../utils/animations.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final AchievementService _achievementService = AchievementService();
  final AuthService _auth = AuthService();
  List<String> _earnedIds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = _auth.currentUser?.uid ?? '';
    final progress = await _achievementService.getAchievementProgress(uid);
    _earnedIds = List<String>.from(progress['earnedIds'] ?? []);
    if (mounted) setState(() => _loading = false);
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'play_arrow':
        return Icons.play_arrow_rounded;
      case 'visibility':
        return Icons.visibility_rounded;
      case 'local_fire_department':
        return Icons.local_fire_department_rounded;
      case 'whatshot':
        return Icons.whatshot_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'chat_bubble':
        return Icons.chat_bubble_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'diamond':
        return Icons.diamond_rounded;
      default:
        return Icons.emoji_events_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'watching':
        return const Color(0xFF2196F3);
      case 'streak':
        return const Color(0xFFFF5722);
      case 'social':
        return const Color(0xFF4CAF50);
      case 'spending':
        return const Color(0xFFFFD700);
      default:
        return Colors.grey;
    }
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
          'Achievements',
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
                // Progress card
                FadeInSlide(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [accent, accent.withAlpha(180)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withAlpha(50),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.emoji_events_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_earnedIds.length} / ${AchievementService.allAchievements.length}',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'achievements unlocked',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value:
                                _earnedIds.length /
                                AchievementService.allAchievements.length,
                            backgroundColor: Colors.white.withAlpha(40),
                            valueColor: const AlwaysStoppedAnimation(
                              Colors.white,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Categories
                ..._buildCategorySection(
                  'Watching',
                  'watching',
                  textColor,
                  subColor,
                  isDark,
                ),
                const SizedBox(height: 16),
                ..._buildCategorySection(
                  'Streaks',
                  'streak',
                  textColor,
                  subColor,
                  isDark,
                ),
                const SizedBox(height: 16),
                ..._buildCategorySection(
                  'Social',
                  'social',
                  textColor,
                  subColor,
                  isDark,
                ),
                const SizedBox(height: 16),
                ..._buildCategorySection(
                  'Spending',
                  'spending',
                  textColor,
                  subColor,
                  isDark,
                ),
              ],
            ),
    );
  }

  List<Widget> _buildCategorySection(
    String title,
    String category,
    Color textColor,
    Color subColor,
    bool isDark,
  ) {
    final achievements = AchievementService.allAchievements
        .where((a) => a['category'] == category)
        .toList();
    final catColor = _getCategoryColor(category);

    return [
      Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: catColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.85,
        ),
        itemCount: achievements.length,
        itemBuilder: (ctx, i) {
          final achievement = achievements[i];
          final isEarned = _earnedIds.contains(achievement['id']);
          return FadeInSlide(
            delay: i * 50,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isEarned
                    ? catColor.withAlpha(15)
                    : (isDark ? const Color(0xFF1A1A2E) : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isEarned
                      ? catColor.withAlpha(60)
                      : (isDark
                            ? Colors.white.withAlpha(10)
                            : Colors.black.withAlpha(10)),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isEarned
                          ? catColor.withAlpha(30)
                          : (isDark
                                ? Colors.white.withAlpha(8)
                                : Colors.grey.withAlpha(30)),
                    ),
                    child: Icon(
                      _getIcon(achievement['icon'] ?? 'star'),
                      color: isEarned
                          ? catColor
                          : (isDark ? Colors.white24 : Colors.grey),
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    achievement['title'] ?? '',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: isEarned ? textColor : subColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isEarned ? 'Unlocked' : achievement['desc'] ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: isEarned
                          ? catColor
                          : (isDark ? Colors.white30 : Colors.grey),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ];
  }
}

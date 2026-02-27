import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/streak_service.dart';
import '../services/auth_service.dart';
import '../utils/animations.dart';

class StreakScreen extends StatefulWidget {
  const StreakScreen({super.key});

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  final StreakService _streakService = StreakService();
  final AuthService _auth = AuthService();
  Map<String, dynamic> _streakInfo = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = _auth.currentUser?.uid ?? '';
    _streakInfo = await _streakService.getStreakInfo(uid);
    if (mounted) setState(() => _loading = false);
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
          'Watch Streak',
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
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _loading = true);
                await _loadData();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Streak count card
                  FadeInSlide(
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: [accent, accent.withAlpha(180)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withAlpha(60),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${_streakInfo['streakCount'] ?? 0}',
                            style: GoogleFonts.outfit(
                              fontSize: 56,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                          Text(
                            'day streak',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Today's progress
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(30),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.play_circle_filled_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_streakInfo['reelsToday'] ?? 0} / ${_streakInfo['reelsNeeded'] ?? 5} reels today',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value:
                                  ((_streakInfo['reelsToday'] ?? 0) /
                                  (_streakInfo['reelsNeeded'] ?? 5)).clamp(0.0, 1.0).toDouble(),
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

                  // Next milestone
                  FadeInSlide(
                    delay: 100,
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
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFFD700).withAlpha(30),
                            ),
                            child: const Icon(
                              Icons.emoji_events_rounded,
                              color: Color(0xFFFFD700),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Next Milestone',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  'Day ${_streakInfo['nextMilestone'] ?? 1} - ${_streakInfo['nextReward'] ?? 5} bonus points',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: subColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: Text(
                              '${((_streakInfo['nextMilestone'] ?? 1) - (_streakInfo['streakCount'] ?? 0))} days away',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Milestone rewards list
                  Text(
                    'Streak Milestones',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...StreakService.streakRewards.entries.map((entry) {
                    final day = entry.key;
                    final reward = entry.value;
                    final currentStreak = _streakInfo['streakCount'] ?? 0;
                    final isReached = currentStreak >= day;
                    return FadeInSlide(
                      delay: 150 + day * 10,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isReached ? accent.withAlpha(15) : cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isReached
                                ? accent.withAlpha(60)
                                : (isDark
                                      ? Colors.white.withAlpha(10)
                                      : Colors.black.withAlpha(10)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isReached
                                    ? accent.withAlpha(30)
                                    : (isDark
                                          ? Colors.white.withAlpha(10)
                                          : Colors.grey.withAlpha(30)),
                              ),
                              child: Icon(
                                isReached
                                    ? Icons.check_circle_rounded
                                    : Icons.local_fire_department_rounded,
                                color: isReached ? accent : subColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Day $day',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    isReached
                                        ? 'Completed!'
                                        : 'Watch 5 reels/day for $day days',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
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
                                color: isReached
                                    ? Colors.green.withAlpha(20)
                                    : const Color(0xFFFFD700).withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '+$reward pts',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isReached
                                      ? Colors.green
                                      : const Color(0xFFFFD700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),

                  // How it works
                  Text(
                    'How It Works',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    Icons.play_circle_outline_rounded,
                    'Watch 5+ reels daily to maintain your streak',
                    cardColor,
                    textColor,
                    subColor,
                  ),
                  _buildInfoTile(
                    Icons.calendar_today_rounded,
                    'Miss a day and your streak resets to 0',
                    cardColor,
                    textColor,
                    subColor,
                  ),
                  _buildInfoTile(
                    Icons.stars_rounded,
                    'Hit milestones to earn bonus points',
                    cardColor,
                    textColor,
                    subColor,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoTile(
    IconData icon,
    String text,
    Color cardColor,
    Color textColor,
    Color subColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: subColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(fontSize: 13, color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

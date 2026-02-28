import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/analytics_data_service.dart';
import '../services/level_service.dart';

class WatchAnalyticsScreen extends StatefulWidget {
  const WatchAnalyticsScreen({super.key});

  @override
  State<WatchAnalyticsScreen> createState() => _WatchAnalyticsScreenState();
}

class _WatchAnalyticsScreenState extends State<WatchAnalyticsScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  final _analytics = AnalyticsDataService();

  UserModel? _user;
  Map<String, int> _dailyCounts = {};
  Map<int, int> _hourlyCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    final results = await Future.wait([
      _firestore.getUser(uid),
      _analytics.getDailyWatchCounts(uid),
      _analytics.getHourlyDistribution(uid),
    ]);

    if (mounted) {
      setState(() {
        _user = results[0] as UserModel?;
        _dailyCounts = results[1] as Map<String, int>;
        _hourlyCounts = results[2] as Map<int, int>;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Watch Analytics',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _loading = true);
                await _loadData();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Stat cards
                  _buildStatCards(isDark, textColor, subColor, cardColor, accent),
                  const SizedBox(height: 24),

                  // Daily activity chart
                  Text(
                    'Daily Activity (Last 7 Days)',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 220,
                    padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(10),
                      ),
                    ),
                    child: _buildLineChart(accent, subColor),
                  ),
                  const SizedBox(height: 24),

                  // Hourly distribution chart
                  Text(
                    'Hourly Activity Distribution',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 220,
                    padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(10),
                      ),
                    ),
                    child: _buildBarChart(accent, subColor),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCards(
    bool isDark,
    Color textColor,
    Color subColor,
    Color cardColor,
    Color accent,
  ) {
    final level = _user?.viewerLevel ?? 'beginner';
    final levelInfo = LevelService.getLevelInfo(level);
    final levelColor = Color(levelInfo['color'] as int);

    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.play_circle_outline_rounded,
            iconColor: accent,
            label: 'Reels Watched',
            value: '${_user?.totalWatchedReels ?? 0}',
            isDark: isDark,
            textColor: textColor,
            subColor: subColor,
            cardColor: cardColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon: Icons.stars_rounded,
            iconColor: const Color(0xFFFFD700),
            label: 'Total Points',
            value: '${_user?.totalPointsEarned ?? 0}',
            isDark: isDark,
            textColor: textColor,
            subColor: subColor,
            cardColor: cardColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon: Icons.shield_rounded,
            iconColor: levelColor,
            label: 'Level',
            value: levelInfo['name'] as String,
            isDark: isDark,
            textColor: textColor,
            subColor: subColor,
            cardColor: cardColor,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
    required Color textColor,
    required Color subColor,
    required Color cardColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(10),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withAlpha(25),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: subColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(Color accent, Color subColor) {
    final entries = _dailyCounts.entries.toList();
    if (entries.isEmpty) {
      return Center(
        child: Text('No data yet', style: GoogleFonts.inter(color: subColor)),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < entries.length; i++) {
      spots.add(FlSpot(i.toDouble(), entries[i].value.toDouble()));
    }

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY / 4).clamp(1, double.infinity),
          getDrawingHorizontalLine: (value) => FlLine(
            color: subColor.withAlpha(30),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: GoogleFonts.inter(fontSize: 10, color: subColor),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= entries.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    entries[idx].key,
                    style: GoogleFonts.inter(fontSize: 9, color: subColor),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (entries.length - 1).toDouble(),
        minY: 0,
        maxY: maxY + 1,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: accent,
            barWidth: 3,
            isStrokeCapRound: true,
            belowBarData: BarAreaData(
              show: true,
              color: accent.withAlpha(30),
            ),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: accent,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(Color accent, Color subColor) {
    final maxVal = _hourlyCounts.values.isEmpty
        ? 1.0
        : _hourlyCounts.values.reduce((a, b) => a > b ? a : b).toDouble();

    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxVal / 4).clamp(1, double.infinity),
          getDrawingHorizontalLine: (value) => FlLine(
            color: subColor.withAlpha(30),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: GoogleFonts.inter(fontSize: 10, color: subColor),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final h = value.toInt();
                if (h % 4 != 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${h}h',
                    style: GoogleFonts.inter(fontSize: 9, color: subColor),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        maxY: maxVal + 1,
        barGroups: List.generate(24, (h) {
          final val = (_hourlyCounts[h] ?? 0).toDouble();
          return BarChartGroupData(
            x: h,
            barRods: [
              BarChartRodData(
                toY: val,
                color: accent.withAlpha(val > 0 ? 200 : 50),
                width: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }
}

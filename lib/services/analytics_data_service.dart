import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AnalyticsDataService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Daily watch counts for the last 7 days
  Future<Map<String, int>> getDailyWatchCounts(String uid) async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final snap = await _db
        .collection('transactions')
        .where('uid', isEqualTo: uid)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
        .orderBy('createdAt', descending: false)
        .get();

    final counts = <String, int>{};
    final fmt = DateFormat('MM/dd');

    // Initialize all 7 days with 0
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      counts[fmt.format(day)] = 0;
    }

    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['type'] != 'earned') continue;
      final ts = (data['createdAt'] as Timestamp?)?.toDate();
      if (ts != null) {
        final key = fmt.format(ts);
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    return counts;
  }

  /// Hourly distribution of watch activity (0-23)
  Future<Map<int, int>> getHourlyDistribution(String uid) async {
    final snap = await _db
        .collection('transactions')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(1000)
        .get();

    final counts = <int, int>{};
    for (int h = 0; h < 24; h++) {
      counts[h] = 0;
    }

    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['type'] != 'earned') continue;
      final ts = (data['createdAt'] as Timestamp?)?.toDate();
      if (ts != null) {
        counts[ts.hour] = (counts[ts.hour] ?? 0) + 1;
      }
    }

    return counts;
  }

  /// Points timeline — daily totals chronologically (last 7 days)
  Future<List<MapEntry<DateTime, int>>> getPointsTimeline(String uid) async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final snap = await _db
        .collection('transactions')
        .where('uid', isEqualTo: uid)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
        .orderBy('createdAt', descending: false)
        .get();

    final dailyPoints = <String, int>{};
    final fmt = DateFormat('yyyy-MM-dd');

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      dailyPoints[fmt.format(day)] = 0;
    }

    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['type'] != 'earned') continue;
      final ts = (data['createdAt'] as Timestamp?)?.toDate();
      final amount = data['amount'] as int? ?? 0;
      if (ts != null) {
        final key = fmt.format(ts);
        dailyPoints[key] = (dailyPoints[key] ?? 0) + amount;
      }
    }

    return dailyPoints.entries
        .map((e) => MapEntry(DateTime.parse(e.key), e.value))
        .toList();
  }
}

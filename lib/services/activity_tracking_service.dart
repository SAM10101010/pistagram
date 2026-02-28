import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityTrackingService {
  final _firestore = FirebaseFirestore.instance;

  String _getDayOfWeek(DateTime date) {
    const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    return days[date.weekday - 1];
  }

  Future<void> logInteraction(String userId) async {
    final now = DateTime.now();
    final day = _getDayOfWeek(now);
    final hour = now.hour;
    final docId = '${userId}_${day}_$hour';

    await _firestore.collection('userActivity').doc(docId).set({
      'id': docId,
      'userId': userId,
      'dayOfWeek': day,
      'hour': hour,
      'interactionCount': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<int, int>> getHourlyActivityCounts(String userId) async {
    final snapshot = await _firestore
        .collection('userActivity')
        .where('userId', isEqualTo: userId)
        .get();

    final Map<int, int> hourlyTotals = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final hour = data['hour'] as int? ?? 0;
      final count = data['interactionCount'] as int? ?? 0;
      hourlyTotals[hour] = (hourlyTotals[hour] ?? 0) + count;
    }
    return hourlyTotals;
  }

  Future<Map<String, int>> getDayOfWeekCounts(String userId) async {
    final snapshot = await _firestore
        .collection('userActivity')
        .where('userId', isEqualTo: userId)
        .get();

    final Map<String, int> dayCounts = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final day = data['dayOfWeek'] as String? ?? '';
      final count = data['interactionCount'] as int? ?? 0;
      dayCounts[day] = (dayCounts[day] ?? 0) + count;
    }
    return dayCounts;
  }

  Future<Map<String, dynamic>> getActivityInsights(String userId) async {
    final hourly = await getHourlyActivityCounts(userId);
    final daily = await getDayOfWeekCounts(userId);

    int peakHour = 0;
    int peakHourCount = 0;
    hourly.forEach((hour, cnt) {
      if (cnt > peakHourCount) {
        peakHour = hour;
        peakHourCount = cnt;
      }
    });

    String peakDay = '';
    int peakDayCount = 0;
    daily.forEach((day, cnt) {
      if (cnt > peakDayCount) {
        peakDay = day;
        peakDayCount = cnt;
      }
    });

    int totalInteractions = 0;
    hourly.forEach((_, cnt) => totalInteractions += cnt);

    return {
      'peakHour': peakHour,
      'peakHourCount': peakHourCount,
      'peakDay': peakDay,
      'peakDayCount': peakDayCount,
      'totalInteractions': totalInteractions,
      'hourlyData': hourly,
      'dailyData': daily,
    };
  }
}

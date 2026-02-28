import 'package:cloud_firestore/cloud_firestore.dart';

class PostingWindowService {
  final _firestore = FirebaseFirestore.instance;

  static const _days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

  String _getDayOfWeek(DateTime date) => _days[date.weekday - 1];

  Future<void> aggregateFollowerActivity(String creatorId) async {
    final followsSnapshot = await _firestore
        .collection('follows')
        .where('followingId', isEqualTo: creatorId)
        .get();

    final followerIds = followsSnapshot.docs.map((d) => d.data()['followerId'] as String).toList();
    if (followerIds.isEmpty) return;

    final Map<String, Map<int, int>> dayHourCounts = {};
    for (final day in _days) {
      dayHourCounts[day] = {};
    }

    for (final followerId in followerIds.take(100)) {
      final activitySnapshot = await _firestore
          .collection('userActivity')
          .where('userId', isEqualTo: followerId)
          .get();

      for (final doc in activitySnapshot.docs) {
        final data = doc.data();
        final day = data['dayOfWeek'] as String? ?? '';
        final hour = data['hour'] as int? ?? 0;
        final count = data['interactionCount'] as int? ?? 0;
        if (dayHourCounts.containsKey(day)) {
          dayHourCounts[day]![hour] = (dayHourCounts[day]![hour] ?? 0) + count;
        }
      }
    }

    final batch = _firestore.batch();
    dayHourCounts.forEach((day, hourMap) {
      hourMap.forEach((hour, cnt) {
        final docId = '${creatorId}_${day}_$hour';
        final ref = _firestore.collection('followerActivity').doc(docId);
        batch.set(ref, {
          'id': docId,
          'creatorId': creatorId,
          'dayOfWeek': day,
          'hour': hour,
          'activeFollowerCount': cnt,
          'avgEngagementRate': cnt / followerIds.length,
          'lastCalculated': FieldValue.serverTimestamp(),
        });
      });
    });
    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> getBestPostingTimes(String creatorId, {int count = 3}) async {
    final snapshot = await _firestore
        .collection('followerActivity')
        .where('creatorId', isEqualTo: creatorId)
        .orderBy('activeFollowerCount', descending: true)
        .limit(count)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'dayOfWeek': data['dayOfWeek'],
        'hour': data['hour'],
        'activeFollowers': data['activeFollowerCount'],
      };
    }).toList();
  }

  Future<Map<String, Map<int, double>>> getWeeklyHeatmap(String creatorId) async {
    final snapshot = await _firestore
        .collection('followerActivity')
        .where('creatorId', isEqualTo: creatorId)
        .get();

    final Map<String, Map<int, double>> heatmap = {};
    for (final day in _days) {
      heatmap[day] = {};
    }

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final day = data['dayOfWeek'] as String? ?? '';
      final hour = data['hour'] as int? ?? 0;
      final rate = (data['avgEngagementRate'] as num? ?? 0.0).toDouble();
      if (heatmap.containsKey(day)) {
        heatmap[day]![hour] = rate;
      }
    }

    return heatmap;
  }

  Future<bool> isGoodPostingTime(String creatorId) async {
    final now = DateTime.now();
    final day = _getDayOfWeek(now);
    final hour = now.hour;
    final docId = '${creatorId}_${day}_$hour';

    final doc = await _firestore.collection('followerActivity').doc(docId).get();
    if (!doc.exists) return false;

    final rate = (doc.data()?['avgEngagementRate'] as num? ?? 0.0).toDouble();
    return rate > 0.3;
  }
}

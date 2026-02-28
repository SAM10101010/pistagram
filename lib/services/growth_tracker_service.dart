import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/weekly_summary_model.dart';

class GrowthTrackerService {
  final _firestore = FirebaseFirestore.instance;

  String _weekId(String userId, DateTime weekStart) {
    final dateStr = '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    return '${userId}_$dateStr';
  }

  DateTime _getWeekStart(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }

  Future<void> generateWeeklySummary(String userId) async {
    final now = DateTime.now();
    final weekStart = _getWeekStart(now);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final docId = _weekId(userId, weekStart);

    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    final userData = userDoc.data()!;
    final currentFollowers = userData['followersCount'] as int? ?? 0;

    final reelsSnapshot = await _firestore
        .collection('reels')
        .where('creatorUid', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
        .get();

    int totalViews = 0, totalLikes = 0, totalComments = 0;
    double totalCompletionRate = 0;
    String topReelId = '';
    int topViews = 0;

    for (final doc in reelsSnapshot.docs) {
      final d = doc.data();
      final views = d['viewsCount'] as int? ?? 0;
      totalViews += views;
      totalLikes += d['likesCount'] as int? ?? 0;
      totalComments += d['commentsCount'] as int? ?? 0;
      totalCompletionRate += (d['completionRate'] as num? ?? 0.0).toDouble();
      if (views > topViews) {
        topViews = views;
        topReelId = d['reelId'] ?? '';
      }
    }

    final avgCompletion = reelsSnapshot.docs.isNotEmpty
        ? totalCompletionRate / reelsSnapshot.docs.length
        : 0.0;

    final existingDoc = await _firestore.collection('creatorWeeklySummary').doc(docId).get();
    final followersStart = existingDoc.exists
        ? (existingDoc.data()?['followersStart'] as int? ?? currentFollowers)
        : currentFollowers;

    final gained = currentFollowers > followersStart ? currentFollowers - followersStart : 0;
    final lost = followersStart > currentFollowers ? followersStart - currentFollowers : 0;

    String trend = 'stable';
    if (gained > lost * 2) trend = 'up';
    if (lost > gained * 2) trend = 'down';

    await _firestore.collection('creatorWeeklySummary').doc(docId).set({
      'id': docId,
      'userId': userId,
      'weekStart': Timestamp.fromDate(weekStart),
      'weekEnd': Timestamp.fromDate(weekEnd),
      'followersStart': followersStart,
      'followersEnd': currentFollowers,
      'followersGained': gained,
      'followersLost': lost,
      'totalViews': totalViews,
      'totalLikes': totalLikes,
      'totalComments': totalComments,
      'avgCompletionRate': avgCompletion,
      'engagementTrend': trend,
      'topReelId': topReelId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<WeeklySummaryModel?> getCurrentWeekSummary(String userId) async {
    final weekStart = _getWeekStart(DateTime.now());
    final docId = _weekId(userId, weekStart);
    final doc = await _firestore.collection('creatorWeeklySummary').doc(docId).get();
    if (!doc.exists) return null;
    return WeeklySummaryModel.fromMap(doc.data()!);
  }

  Future<List<WeeklySummaryModel>> getWeeklySummaries(String userId, {int weeks = 12}) async {
    final snapshot = await _firestore
        .collection('creatorWeeklySummary')
        .where('userId', isEqualTo: userId)
        .orderBy('weekStart', descending: true)
        .limit(weeks)
        .get();

    return snapshot.docs
        .map((doc) => WeeklySummaryModel.fromMap(doc.data()))
        .toList();
  }

  Future<Map<String, dynamic>> getGrowthTrends(String userId) async {
    final summaries = await getWeeklySummaries(userId, weeks: 4);
    if (summaries.isEmpty) {
      return {'trend': 'no_data', 'avgViews': 0, 'avgLikes': 0, 'followerChange': 0};
    }

    int totalViews = 0, totalLikes = 0, followerChange = 0;
    for (final s in summaries) {
      totalViews += s.totalViews;
      totalLikes += s.totalLikes;
      followerChange += s.followerChange;
    }

    return {
      'trend': followerChange > 0 ? 'growing' : (followerChange < 0 ? 'declining' : 'stable'),
      'avgViews': totalViews ~/ summaries.length,
      'avgLikes': totalLikes ~/ summaries.length,
      'followerChange': followerChange,
      'weeksTracked': summaries.length,
    };
  }
}

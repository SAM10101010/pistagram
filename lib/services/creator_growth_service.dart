import 'package:cloud_firestore/cloud_firestore.dart';

class CreatorGrowthService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getGrowthMetrics(String uid) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists) return {};
    final data = userDoc.data()!;

    final reelsSnap = await _db.collection('reels')
        .where('creatorUid', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .get();

    double avgCompletion = 0;
    double avgLikeRate = 0;
    int totalViews = 0;

    for (final reel in reelsSnap.docs) {
      final rd = reel.data();
      avgCompletion += (rd['completionRate'] ?? 0.0).toDouble();
      final views = (rd['viewsCount'] ?? 0) as int;
      final likes = (rd['likesCount'] ?? 0) as int;
      totalViews += views;
      avgLikeRate += views > 0 ? likes / views : 0;
    }

    final count = reelsSnap.docs.length;
    if (count > 0) {
      avgCompletion /= count;
      avgLikeRate /= count;
    }

    final followers = (data['followersCount'] ?? 0) as int;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final accountDays = DateTime.now().difference(createdAt).inDays;
    final growthRate = accountDays > 0 ? followers / accountDays : 0.0;

    // Determine badges
    final badges = <String>[];
    final consistency = (data['consistencyScore'] ?? 0.0).toDouble();
    if (consistency >= 70) badges.add('Consistent Creator');
    if (avgCompletion >= 60) badges.add('High Retention Creator');

    return {
      'growthRate': growthRate,
      'retentionTrend': avgCompletion,
      'engagementDepth': avgLikeRate * 100,
      'totalViews': totalViews,
      'reelCount': count,
      'badges': badges,
      'consistencyScore': consistency,
    };
  }
}

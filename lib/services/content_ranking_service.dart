import 'package:cloud_firestore/cloud_firestore.dart';

class ContentRankingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const List<String> contentTypes = [
    'tutorial',
    'story',
    'insight',
    'entertainment',
    'other',
  ];

  Future<void> setContentType(String reelId, String type) async {
    await _db.collection('reels').doc(reelId).update({
      'contentType': type,
    });
  }

  Future<List<Map<String, dynamic>>> getReelsByCategory(
    String category, {
    int limit = 20,
  }) async {
    final snap = await _db.collection('reels')
        .where('contentType', isEqualTo: category)
        .where('isActive', isEqualTo: true)
        .orderBy('qualityScore', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<Map<String, int>> getCategoryDistribution() async {
    final counts = <String, int>{};
    for (final type in contentTypes) {
      final snap = await _db.collection('reels')
          .where('contentType', isEqualTo: type)
          .where('isActive', isEqualTo: true)
          .count()
          .get();
      counts[type] = snap.count ?? 0;
    }
    return counts;
  }
}

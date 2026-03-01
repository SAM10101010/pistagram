import 'package:cloud_firestore/cloud_firestore.dart';

class TransparencyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getReelRankingBreakdown(String reelId) async {
    final doc = await _db.collection('reels').doc(reelId).get();
    if (!doc.exists) return {};
    final data = doc.data()!;

    return {
      'qualityScore': (data['qualityScore'] ?? 0.0).toDouble(),
      'retentionPercent': (data['retentionPercent'] ?? 0.0).toDouble(),
      'discussionDepth': (data['discussionDepth'] ?? 0.0).toDouble(),
      'saveRate': (data['saveRate'] ?? 0.0).toDouble(),
      'momentumScore': (data['momentumScore'] ?? 0.0).toDouble(),
      'lifecycleStage': data['lifecycleStage'] ?? 'fresh',
      'viewVelocity': (data['viewVelocity'] ?? 0.0).toDouble(),
      'contentType': data['contentType'] ?? 'other',
      'qualityVerified': data['qualityVerified'] ?? false,
      'rankingWeight': (data['rankingWeight'] ?? 1.0).toDouble(),
      'visibilityMultiplier': (data['visibilityMultiplier'] ?? 1.0).toDouble(),
    };
  }

  Future<List<Map<String, dynamic>>> getRankingHistory(String reelId) async {
    final snap = await _db.collection('reels').doc(reelId)
        .collection('rankingHistory')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }
}

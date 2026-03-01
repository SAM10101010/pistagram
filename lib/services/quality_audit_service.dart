import 'package:cloud_firestore/cloud_firestore.dart';

class QualityAuditService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> calculateQualityScore(String reelId) async {
    final reelDoc = await _db.collection('reels').doc(reelId).get();
    if (!reelDoc.exists) return {};
    final data = reelDoc.data()!;

    final views = (data['viewsCount'] ?? 0) as int;
    final likes = (data['likesCount'] ?? 0) as int;
    final completionRate = (data['completionRate'] ?? 0.0).toDouble();

    // Save rate
    final savesSnap = await _db.collection('saves')
        .where('reelId', isEqualTo: reelId).get();
    final saves = savesSnap.docs.length;
    final saveRate = views > 0 ? (saves / views) * 100 : 0.0;

    // Discussion depth = avg replies per comment
    final commentsSnap = await _db.collection('comments')
        .where('reelId', isEqualTo: reelId)
        .where('parentId', isEqualTo: '').get();
    double discussionDepth = 0;
    if (commentsSnap.docs.isNotEmpty) {
      int totalReplies = 0;
      for (final c in commentsSnap.docs) {
        totalReplies += (c.data()['repliesCount'] ?? 0) as int;
      }
      discussionDepth = totalReplies / commentsSnap.docs.length;
    }

    // Retention percent
    final retentionPercent = completionRate;

    // Quality Score (weighted formula)
    final weight = (data['qualityScoreWeight'] ?? 1.0).toDouble();
    final qualityScore = ((retentionPercent * 0.35) +
        (discussionDepth * 10 * 0.25) +
        (saveRate * 0.25) +
        ((likes / (views > 0 ? views : 1)) * 100 * 0.15)) * weight;

    final verified = qualityScore >= 70.0;

    await _db.collection('reels').doc(reelId).update({
      'qualityScore': qualityScore.clamp(0, 100),
      'retentionPercent': retentionPercent,
      'discussionDepth': discussionDepth,
      'saveRate': saveRate,
      'qualityVerified': verified,
    });

    return {
      'qualityScore': qualityScore.clamp(0, 100),
      'retentionPercent': retentionPercent,
      'discussionDepth': discussionDepth,
      'saveRate': saveRate,
      'qualityVerified': verified,
    };
  }

  Future<List<Map<String, dynamic>>> getTopQualityReels({int limit = 20}) async {
    final snap = await _db.collection('reels')
        .where('isActive', isEqualTo: true)
        .where('qualityVerified', isEqualTo: true)
        .orderBy('qualityScore', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }
}

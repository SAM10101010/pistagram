import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/close_friend_analytics_model.dart';

class CloseFriendAnalyticsService {
  final _firestore = FirebaseFirestore.instance;

  String _docId(String ownerId, String supporterId) => '${ownerId}_$supporterId';

  Future<void> _incrementField(String ownerId, String supporterId, String field) async {
    final docId = _docId(ownerId, supporterId);
    final ref = _firestore.collection('closeFriendAnalytics').doc(docId);

    await ref.set({
      'id': docId,
      'ownerId': ownerId,
      'supporterId': supporterId,
      field: FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _recalculateScore(docId);
  }

  Future<void> _recalculateScore(String docId) async {
    final ref = _firestore.collection('closeFriendAnalytics').doc(docId);
    final doc = await ref.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final storyViews = (data['storyViews'] as int? ?? 0);
    final storyReplies = (data['storyReplies'] as int? ?? 0);
    final reelLikes = (data['reelLikes'] as int? ?? 0);
    final reelComments = (data['reelComments'] as int? ?? 0);

    final score = (storyViews * 1) + (storyReplies * 3) + (reelLikes * 2) + (reelComments * 4);
    await ref.update({'interactionScore': score.toDouble()});
  }

  Future<void> onStoryViewed(String ownerId, String viewerId, double watchPercent) async {
    await _incrementField(ownerId, viewerId, 'storyViews');
    if (watchPercent > 0) {
      final docId = _docId(ownerId, viewerId);
      final ref = _firestore.collection('closeFriendAnalytics').doc(docId);
      final doc = await ref.get();
      final views = (doc.data()?['storyViews'] as int? ?? 1);
      final oldAvg = (doc.data()?['avgStoryWatchPercent'] as num? ?? 0.0).toDouble();
      final newAvg = ((oldAvg * (views - 1)) + watchPercent) / views;
      await ref.update({'avgStoryWatchPercent': newAvg});
    }
  }

  Future<void> onStoryReplied(String ownerId, String replierId) async {
    await _incrementField(ownerId, replierId, 'storyReplies');
  }

  Future<void> onReelLiked(String ownerId, String likerId) async {
    await _incrementField(ownerId, likerId, 'reelLikes');
  }

  Future<void> onReelCommented(String ownerId, String commenterId) async {
    await _incrementField(ownerId, commenterId, 'reelComments');
  }

  Future<List<CloseFriendAnalyticsModel>> getTopSupporters(String ownerId, {int limit = 3}) async {
    final snapshot = await _firestore
        .collection('closeFriendAnalytics')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('interactionScore', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => CloseFriendAnalyticsModel.fromMap(doc.data()))
        .toList();
  }

  Future<List<CloseFriendAnalyticsModel>> suggestCloseFriends(String ownerId, {int limit = 10}) async {
    final snapshot = await _firestore
        .collection('closeFriendAnalytics')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('interactionScore', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => CloseFriendAnalyticsModel.fromMap(doc.data()))
        .where((m) => m.interactionScore > 5)
        .toList();
  }
}

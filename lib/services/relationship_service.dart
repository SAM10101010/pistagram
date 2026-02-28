import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/relationship_score_model.dart';

class RelationshipService {
  final _firestore = FirebaseFirestore.instance;

  String _getDocId(String userA, String userB) {
    final sorted = [userA, userB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> _incrementField(String userA, String userB, String field) async {
    final docId = _getDocId(userA, userB);
    final sorted = [userA, userB]..sort();
    final ref = _firestore.collection('relationshipScores').doc(docId);

    await ref.set({
      'id': docId,
      'userA': sorted[0],
      'userB': sorted[1],
      field: FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _recalculateScore(docId);
  }

  Future<void> _recalculateScore(String docId) async {
    final ref = _firestore.collection('relationshipScores').doc(docId);
    final doc = await ref.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final comments = (data['commentsExchanged'] as int? ?? 0);
    final shares = (data['reelSharesExchanged'] as int? ?? 0);
    final likes = (data['mutualLikes'] as int? ?? 0);
    final dms = (data['dmCount'] as int? ?? 0);

    final score = (comments * 3) + (shares * 5) + (likes * 2) + (dms * 1);
    await ref.update({'score': score.toDouble()});
  }

  Future<void> onCommentExchange(String userA, String userB) async {
    await _incrementField(userA, userB, 'commentsExchanged');
  }

  Future<void> onReelShare(String fromUser, String toUser) async {
    await _incrementField(fromUser, toUser, 'reelSharesExchanged');
  }

  Future<void> onMutualLike(String userA, String userB) async {
    await _incrementField(userA, userB, 'mutualLikes');
  }

  Future<void> onDMSent(String fromUser, String toUser) async {
    await _incrementField(fromUser, toUser, 'dmCount');
  }

  Future<RelationshipScoreModel?> getRelationship(String userA, String userB) async {
    final docId = _getDocId(userA, userB);
    final doc = await _firestore.collection('relationshipScores').doc(docId).get();
    if (!doc.exists) return null;
    return RelationshipScoreModel.fromMap(doc.data()!);
  }

  Future<List<RelationshipScoreModel>> getTopRelationships(String userId, {int limit = 10}) async {
    final asA = await _firestore
        .collection('relationshipScores')
        .where('userA', isEqualTo: userId)
        .orderBy('score', descending: true)
        .limit(limit)
        .get();

    final asB = await _firestore
        .collection('relationshipScores')
        .where('userB', isEqualTo: userId)
        .orderBy('score', descending: true)
        .limit(limit)
        .get();

    final all = [
      ...asA.docs.map((d) => RelationshipScoreModel.fromMap(d.data())),
      ...asB.docs.map((d) => RelationshipScoreModel.fromMap(d.data())),
    ];

    all.sort((a, b) => b.score.compareTo(a.score));
    return all.take(limit).toList();
  }
}

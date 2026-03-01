import 'package:cloud_firestore/cloud_firestore.dart';

class ChallengeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getActiveChallenges() async {
    final now = Timestamp.fromDate(DateTime.now());
    final snap = await _db.collection('challenges')
        .where('isActive', isEqualTo: true)
        .where('endDate', isGreaterThan: now)
        .orderBy('endDate')
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> joinChallenge(String challengeId, String uid) async {
    await _db.collection('challenges').doc(challengeId)
        .collection('participants').doc(uid).set({
      'uid': uid,
      'joinedAt': Timestamp.fromDate(DateTime.now()),
      'score': 0,
    });
    await _db.collection('challenges').doc(challengeId).update({
      'participantCount': FieldValue.increment(1),
    });
  }

  Future<void> submitEntry(String challengeId, String uid, String reelId) async {
    await _db.collection('challenges').doc(challengeId)
        .collection('entries').doc('${uid}_$reelId').set({
      'uid': uid,
      'reelId': reelId,
      'submittedAt': Timestamp.fromDate(DateTime.now()),
      'score': 0,
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> getChallengeLeaderboard(
    String challengeId, {
    int limit = 20,
  }) async {
    final snap = await _db.collection('challenges').doc(challengeId)
        .collection('entries')
        .where('status', isEqualTo: 'approved')
        .orderBy('score', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<bool> hasJoined(String challengeId, String uid) async {
    final doc = await _db.collection('challenges').doc(challengeId)
        .collection('participants').doc(uid).get();
    return doc.exists;
  }
}

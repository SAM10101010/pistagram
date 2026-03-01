import 'package:cloud_firestore/cloud_firestore.dart';

class ModerationQueueService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> flagForModeration(String reelId, String reason) async {
    await _db.collection('moderationQueue').doc(reelId).set({
      'reelId': reelId,
      'reason': reason,
      'status': 'pending',
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'priority': 'medium',
    }, SetOptions(merge: true));

    // Temporarily hide from explore
    await _db.collection('reels').doc(reelId).update({
      'shadowLimited': true,
      'visibilityMultiplier': 0.1,
    });
  }

  Future<bool> isInQueue(String reelId) async {
    final doc = await _db.collection('moderationQueue').doc(reelId).get();
    return doc.exists && doc.data()?['status'] == 'pending';
  }
}

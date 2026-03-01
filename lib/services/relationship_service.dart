import 'package:cloud_firestore/cloud_firestore.dart';

class RelationshipService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getRelationshipStrength(String uid1, String uid2) async {
    // Count mutual interactions
    int likeScore = 0;
    int commentScore = 0;
    int messageScore = 0;

    // Likes from uid1 on uid2's reels
    final uid2Reels = await _db.collection('reels')
        .where('creatorUid', isEqualTo: uid2)
        .limit(50).get();
    for (final reel in uid2Reels.docs) {
      final liked = await _db.collection('likes')
          .doc('${uid1}_${reel.id}').get();
      if (liked.exists) likeScore++;
    }

    // Comments from uid1 on uid2's reels
    final comments = await _db.collection('comments')
        .where('uid', isEqualTo: uid1)
        .limit(100).get();
    for (final c in comments.docs) {
      final reelId = c.data()['reelId'] ?? '';
      final reelDoc = await _db.collection('reels').doc(reelId).get();
      if (reelDoc.exists && reelDoc.data()?['creatorUid'] == uid2) {
        commentScore++;
      }
    }

    // Messages between them
    final participants = [uid1, uid2]..sort();
    final chatId = '${participants[0]}_${participants[1]}';
    final chatDoc = await _db.collection('chats').doc(chatId).get();
    if (chatDoc.exists) messageScore = 10;

    double total = (likeScore * 1.0 + commentScore * 3.0 + messageScore * 2.0);
    String label = 'Acquaintance';
    if (total >= 30) {
      label = 'Strong Connection';
    } else if (total >= 15) {
      label = 'Frequent Interactor';
    }

    return {
      'totalScore': total,
      'label': label,
      'likeScore': likeScore,
      'commentScore': commentScore,
      'messageScore': messageScore,
    };
  }

  Future<List<Map<String, dynamic>>> getStrongConnections(String uid) async {
    final followsSnap = await _db.collection('follows')
        .where('followerId', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .limit(50).get();

    final connections = <Map<String, dynamic>>[];
    for (final follow in followsSnap.docs) {
      final targetUid = follow.data()['followingId'] ?? '';
      if (targetUid.isEmpty) continue;
      final strength = await getRelationshipStrength(uid, targetUid);
      if ((strength['totalScore'] as double) >= 15) {
        connections.add({
          'uid': targetUid,
          ...strength,
        });
      }
    }
    connections.sort((a, b) => (b['totalScore'] as double).compareTo(a['totalScore'] as double));
    return connections;
  }
}

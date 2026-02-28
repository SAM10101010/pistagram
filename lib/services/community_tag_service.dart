import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityTagService {
  final _firestore = FirebaseFirestore.instance;

  static const categories = [
    'tutorial', 'opinion', 'story', 'news', 'entertainment',
    'lifestyle', 'comedy', 'education', 'sports', 'music',
  ];

  Future<void> voteCategory(String reelId, String voterId, String category) async {
    final docId = '${reelId}_$voterId';
    final voteRef = _firestore.collection('reelCategoryVotes').doc(docId);
    final reelRef = _firestore.collection('reels').doc(reelId);

    final existingVote = await voteRef.get();
    if (existingVote.exists) {
      await changeVote(reelId, voterId, category);
      return;
    }

    final batch = _firestore.batch();
    batch.set(voteRef, {
      'id': docId,
      'reelId': reelId,
      'voterId': voterId,
      'category': category,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(reelRef, {
      'categoryVoteCounts.$category': FieldValue.increment(1),
    });
    await batch.commit();
    await autoAssignCategory(reelId);
  }

  Future<void> changeVote(String reelId, String voterId, String newCategory) async {
    final docId = '${reelId}_$voterId';
    final voteRef = _firestore.collection('reelCategoryVotes').doc(docId);
    final reelRef = _firestore.collection('reels').doc(reelId);

    final voteDoc = await voteRef.get();
    if (!voteDoc.exists) return;

    final oldCategory = voteDoc.data()!['category'] as String;
    if (oldCategory == newCategory) return;

    final batch = _firestore.batch();
    batch.update(voteRef, {'category': newCategory});
    batch.update(reelRef, {
      'categoryVoteCounts.$oldCategory': FieldValue.increment(-1),
      'categoryVoteCounts.$newCategory': FieldValue.increment(1),
    });
    await batch.commit();
    await autoAssignCategory(reelId);
  }

  Future<String?> getTopCategory(String reelId) async {
    final doc = await _firestore.collection('reels').doc(reelId).get();
    if (!doc.exists) return null;

    final voteCounts = Map<String, int>.from(doc.data()?['categoryVoteCounts'] ?? {});
    if (voteCounts.isEmpty) return null;

    String? topCategory;
    int topCount = 0;
    voteCounts.forEach((cat, cnt) {
      if (cnt > topCount) {
        topCategory = cat;
        topCount = cnt;
      }
    });
    return topCategory;
  }

  Future<void> autoAssignCategory(String reelId) async {
    final doc = await _firestore.collection('reels').doc(reelId).get();
    if (!doc.exists) return;

    final voteCounts = Map<String, int>.from(doc.data()?['categoryVoteCounts'] ?? {});
    int totalVotes = 0;
    String? topCategory;
    int topCount = 0;

    voteCounts.forEach((cat, cnt) {
      totalVotes += cnt;
      if (cnt > topCount) {
        topCategory = cat;
        topCount = cnt;
      }
    });

    if (totalVotes >= 10 && topCategory != null) {
      await _firestore.collection('reels').doc(reelId).update({
        'communityCategory': topCategory,
      });
    }
  }

  Future<String?> getUserVote(String reelId, String userId) async {
    final docId = '${reelId}_$userId';
    final doc = await _firestore.collection('reelCategoryVotes').doc(docId).get();
    if (!doc.exists) return null;
    return doc.data()?['category'] as String?;
  }
}

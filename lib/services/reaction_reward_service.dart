import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import 'firestore_service.dart';

class ReactionRewardService {
  final FirestoreService _firestore = FirestoreService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  static const int likeBonusPoints = 2;
  static const int commentBonusPoints = 3;
  static const int maxDailyBonus = 30;

  CollectionReference<Map<String, dynamic>> get _engagements =>
      _db.collection('reelEngagements');

  /// Called when a reel is fully watched. Creates the engagement record.
  Future<void> onReelWatched(String uid, String reelId, int basePoints) async {
    final docId = '${uid}_$reelId';
    final existing = await _engagements.doc(docId).get();
    if (existing.exists) return; // Already tracked

    await _engagements.doc(docId).set({
      'uid': uid,
      'reelId': reelId,
      'watched': true,
      'liked': false,
      'commented': false,
      'basePoints': basePoints,
      'bonusPoints': 0,
      'awardedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Called when user likes a reel. Awards bonus if they watched it.
  Future<int> onReelLiked(String uid, String reelId) async {
    final docId = '${uid}_$reelId';
    final doc = await _engagements.doc(docId).get();
    if (!doc.exists || doc.data()?['watched'] != true) return 0;
    if (doc.data()?['liked'] == true) return 0;

    // Check daily bonus cap
    if (await _hasReachedBonusCap(uid)) return 0;

    await _engagements.doc(docId).update({
      'liked': true,
      'bonusPoints': FieldValue.increment(likeBonusPoints),
    });

    // Award bonus points
    final txn = TransactionModel(
      id: _uuid.v4(),
      uid: uid,
      type: 'bonus',
      amount: likeBonusPoints,
      reason: 'Engagement bonus: liked watched reel',
      reelId: reelId,
    );
    await _firestore.addTransaction(txn);
    await _firestore.updatePointsBalance(uid, likeBonusPoints);

    return likeBonusPoints;
  }

  /// Called when user comments on a reel. Awards bonus if they watched it.
  Future<int> onReelCommented(String uid, String reelId) async {
    final docId = '${uid}_$reelId';
    final doc = await _engagements.doc(docId).get();
    if (!doc.exists || doc.data()?['watched'] != true) return 0;
    if (doc.data()?['commented'] == true) return 0;

    // Check daily bonus cap
    if (await _hasReachedBonusCap(uid)) return 0;

    await _engagements.doc(docId).update({
      'commented': true,
      'bonusPoints': FieldValue.increment(commentBonusPoints),
    });

    final txn = TransactionModel(
      id: _uuid.v4(),
      uid: uid,
      type: 'bonus',
      amount: commentBonusPoints,
      reason: 'Engagement bonus: commented on watched reel',
      reelId: reelId,
    );
    await _firestore.addTransaction(txn);
    await _firestore.updatePointsBalance(uid, commentBonusPoints);

    return commentBonusPoints;
  }

  Future<bool> _hasReachedBonusCap(String uid) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final snap = await _db
        .collection('transactions')
        .where('uid', isEqualTo: uid)
        .where('type', isEqualTo: 'bonus')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .get();
    int totalBonus = 0;
    for (final doc in snap.docs) {
      totalBonus += (doc.data()['amount'] as int?) ?? 0;
    }
    return totalBonus >= maxDailyBonus;
  }
}

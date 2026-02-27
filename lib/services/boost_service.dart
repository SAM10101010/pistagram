import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import 'firestore_service.dart';

class BoostService {
  final FirestoreService _firestore = FirestoreService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _boosts =>
      _db.collection('boostedReels');

  static const Map<int, Map<String, dynamic>> boostPricing = {
    1: {'points': 50, 'hours': 6, 'label': 'Basic Boost'},
    2: {'points': 100, 'hours': 12, 'label': 'Super Boost'},
    3: {'points': 200, 'hours': 24, 'label': 'Mega Boost'},
  };

  Future<bool> boostReel(String uid, String reelId, int level) async {
    final pricing = boostPricing[level];
    if (pricing == null) return false;

    final cost = pricing['points'] as int;
    final hours = pricing['hours'] as int;

    // Verify ownership
    final reel = await _firestore.getReel(reelId);
    if (reel == null || reel.creatorUid != uid) return false;

    // Check balance
    final user = await _firestore.getUser(uid);
    if (user == null || user.pointsBalance < cost) return false;

    // Deduct points
    final txn = TransactionModel(
      id: _uuid.v4(),
      uid: uid,
      type: 'redeemed',
      amount: cost,
      reason: 'Reel boost level $level',
      reelId: reelId,
    );
    await _firestore.addTransaction(txn);
    await _firestore.updatePointsBalance(uid, -cost);

    // Create boost
    await _boosts.doc(reelId).set({
      'reelId': reelId,
      'creatorUid': uid,
      'boostLevel': level,
      'boostExpiry': Timestamp.fromDate(
        DateTime.now().add(Duration(hours: hours)),
      ),
      'pointsSpent': cost,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });

    return true;
  }

  Future<List<String>> getActiveBoostedReelIds() async {
    final now = DateTime.now();
    final snap = await _boosts
        .where('boostExpiry', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('boostExpiry')
        .get();
    return snap.docs.map((d) => d.data()['reelId'] as String).toList();
  }

  Future<bool> isReelBoosted(String reelId) async {
    final doc = await _boosts.doc(reelId).get();
    if (!doc.exists) return false;
    final expiry = (doc.data()?['boostExpiry'] as Timestamp?)?.toDate();
    return expiry != null && expiry.isAfter(DateTime.now());
  }

  Future<Map<String, dynamic>?> getBoostInfo(String reelId) async {
    final doc = await _boosts.doc(reelId).get();
    if (!doc.exists) return null;
    return doc.data();
  }
}

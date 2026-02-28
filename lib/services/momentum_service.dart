import 'package:cloud_firestore/cloud_firestore.dart';

class MomentumService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> recalculateMomentum(String reelId) async {
    final ref = _firestore.collection('reels').doc(reelId);
    final doc = await ref.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final currentRate = (data['engagementLastHour'] as num? ?? 0.0).toDouble();
    final previousRate = (data['engagementPreviousHour'] as num? ?? 0.0).toDouble();

    final score = calculateMomentumScore(currentRate, previousRate);
    final status = getMomentumStatus(score);

    await ref.update({
      'momentumScore': score,
      'momentumStatus': status,
    });
  }

  double calculateMomentumScore(double currentRate, double previousRate) {
    if (previousRate == 0) return currentRate > 0 ? 100.0 : 0.0;
    return ((currentRate - previousRate) / previousRate) * 100;
  }

  String getMomentumStatus(double score) {
    if (score > 20) return 'rising';
    if (score < -20) return 'declining';
    return 'stable';
  }

  Future<void> updateEngagementRate(String reelId) async {
    final ref = _firestore.collection('reels').doc(reelId);

    await _firestore.runTransaction((txn) async {
      final doc = await txn.get(ref);
      if (!doc.exists) return;

      final data = doc.data()!;
      final currentLastHour = (data['engagementLastHour'] as num? ?? 0.0).toDouble();

      txn.update(ref, {
        'engagementPreviousHour': currentLastHour,
        'engagementLastHour': FieldValue.increment(1),
      });
    });
  }

  Future<List<Map<String, dynamic>>> getRisingMomentumReels({int limit = 20}) async {
    final snapshot = await _firestore
        .collection('reels')
        .where('momentumStatus', isEqualTo: 'rising')
        .where('isActive', isEqualTo: true)
        .orderBy('momentumScore', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }
}

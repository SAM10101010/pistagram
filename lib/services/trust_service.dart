import 'package:cloud_firestore/cloud_firestore.dart';
import 'account_health_service.dart';

class TrustService {
  final _firestore = FirebaseFirestore.instance;
  final _healthService = AccountHealthService();

  Future<double> calculateTrustScore(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return 50.0;

    final data = doc.data()!;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final accountAgeDays = DateTime.now().difference(createdAt).inDays;
    final validReports = data['validReportsFiled'] as int? ?? 0;
    final reportsReceived = data['reportsReceived'] as int? ?? 0;
    final spamFlags = data['spamDetectionFlags'] as int? ?? 0;

    double score = 50.0;
    score += (accountAgeDays / 30).clamp(0, 15);
    score += (validReports * 2).clamp(0, 10).toDouble();
    score -= (reportsReceived * 3).clamp(0, 20).toDouble();
    score -= (spamFlags * 5).clamp(0, 25).toDouble();
    score = score.clamp(0, 100);

    final trustLevel = getTrustLevel(score);
    await _firestore.collection('users').doc(userId).update({
      'trustScore': score,
      'trustLevel': trustLevel,
    });

    return score;
  }

  String getTrustLevel(double score) {
    if (score > 75) return 'high';
    if (score >= 40) return 'medium';
    return 'low';
  }

  Future<void> onReportFiled(String reporterId, bool wasValid) async {
    final batch = _firestore.batch();
    final ref = _firestore.collection('users').doc(reporterId);
    batch.update(ref, {
      'reportsFiled': FieldValue.increment(1),
      if (wasValid) 'validReportsFiled': FieldValue.increment(1),
    });
    await batch.commit();
    await calculateTrustScore(reporterId);
    await _healthService.recalculateAndStore(reporterId,
        component: 'trust', reason: 'Report filed');
  }

  Future<void> onReportReceived(String userId, bool wasValid) async {
    await _firestore.collection('users').doc(userId).update({
      'reportsReceived': FieldValue.increment(1),
    });
    await calculateTrustScore(userId);
    await _healthService.recalculateAndStore(userId,
        component: 'reports', reason: 'Report received');
  }

  Future<void> onSpamDetected(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'spamDetectionFlags': FieldValue.increment(1),
    });
    await calculateTrustScore(userId);
    await _healthService.recalculateAndStore(userId,
        component: 'spam', reason: 'Spam detected');
  }

  bool shouldHighlightComment(double trustScore) => trustScore > 80;

  double getReportWeight(double trustScore) {
    if (trustScore > 75) return 1.5;
    if (trustScore >= 40) return 1.0;
    return 0.5;
  }

  bool shouldLimitVisibility(double trustScore) => trustScore < 30;
}

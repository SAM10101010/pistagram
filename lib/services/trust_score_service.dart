import 'package:cloud_firestore/cloud_firestore.dart';

class TrustScoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String calculateTrustLevel(double score) {
    if (score >= 80) return 'elite';
    if (score >= 60) return 'high';
    if (score >= 30) return 'normal';
    return 'low';
  }

  Future<Map<String, dynamic>> recalculateTrustScore(String uid) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists) return {};
    final data = userDoc.data()!;

    final reportsFiled = (data['reportsFiled'] ?? 0) as int;
    final validReports = (data['validReportsFiled'] ?? 0) as int;
    final reportsReceived = (data['reportsReceived'] ?? 0) as int;
    final spamFlags = (data['spamDetectionFlags'] ?? 0) as int;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final accountAgeDays = DateTime.now().difference(createdAt).inDays;

    // Score components
    double ageBonus = (accountAgeDays / 365 * 15).clamp(0, 15);
    double reportAccuracy = reportsFiled > 0
        ? (validReports / reportsFiled) * 20
        : 10;
    double reportPenalty = (reportsReceived * 3.0).clamp(0, 30);
    double spamPenalty = (spamFlags * 5.0).clamp(0, 25);

    double score = (50 + ageBonus + reportAccuracy - reportPenalty - spamPenalty).clamp(0, 100);
    String level = calculateTrustLevel(score);

    await _db.collection('users').doc(uid).update({
      'trustScore': score,
      'trustLevel': level,
    });

    return {
      'trustScore': score,
      'trustLevel': level,
      'ageBonus': ageBonus,
      'reportAccuracy': reportAccuracy,
      'reportPenalty': reportPenalty,
      'spamPenalty': spamPenalty,
    };
  }

  Future<Map<String, dynamic>> getTrustBreakdown(String uid) async {
    return await recalculateTrustScore(uid);
  }
}

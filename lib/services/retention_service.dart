import 'package:cloud_firestore/cloud_firestore.dart';

class RetentionService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> recordWatchDepth(String reelId, double depth) async {
    final ref = _firestore.collection('reels').doc(reelId);

    await _firestore.runTransaction((txn) async {
      final doc = await txn.get(ref);
      if (!doc.exists) return;

      final data = doc.data()!;
      final totalSessions = (data['totalWatchSessions'] as int? ?? 0) + 1;
      final oldAvg = (data['avgWatchDepth'] as num? ?? 0.0).toDouble();
      final newAvg = ((oldAvg * (totalSessions - 1)) + depth) / totalSessions;
      final highRetention = (data['highRetentionViews'] as int? ?? 0) + (depth >= 0.75 ? 1 : 0);

      txn.update(ref, {
        'avgWatchDepth': newAvg,
        'totalWatchSessions': totalSessions,
        'highRetentionViews': highRetention,
      });
    });
  }

  Future<double> getAverageWatchDepth(String reelId) async {
    final doc = await _firestore.collection('reels').doc(reelId).get();
    if (!doc.exists) return 0.0;
    return (doc.data()?['avgWatchDepth'] as num? ?? 0.0).toDouble();
  }

  bool isHighRetention(double avgDepth) => avgDepth >= 0.75;

  String getRetentionLabel(double avgDepth) {
    if (avgDepth >= 0.9) return 'Exceptional Retention';
    if (avgDepth >= 0.75) return 'High Retention';
    if (avgDepth >= 0.5) return 'Good Retention';
    if (avgDepth >= 0.25) return 'Average Retention';
    return 'Low Retention';
  }
}

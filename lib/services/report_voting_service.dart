import 'package:cloud_firestore/cloud_firestore.dart';

class ReportVotingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> castVote({
    required String reportId,
    required String voterUid,
    required bool isValid,
  }) async {
    final voteDoc = _db.collection('reportVotes').doc('${voterUid}_$reportId');
    await voteDoc.set({
      'reportId': reportId,
      'voterUid': voterUid,
      'isValid': isValid,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });

    // Update report vote counts
    final field = isValid ? 'validVotes' : 'invalidVotes';
    await _db.collection('reports').doc(reportId).update({
      field: FieldValue.increment(1),
      'totalVotes': FieldValue.increment(1),
    });

    // Check threshold for auto-hide
    final reportDoc = await _db.collection('reports').doc(reportId).get();
    if (reportDoc.exists) {
      final data = reportDoc.data()!;
      final validVotes = (data['validVotes'] ?? 0) as int;
      final totalVotes = (data['totalVotes'] ?? 0) as int;
      if (totalVotes >= 5 && validVotes / totalVotes >= 0.7) {
        final targetId = data['targetId'] ?? '';
        final targetType = data['targetType'] ?? '';
        if (targetType == 'reel' && targetId.isNotEmpty) {
          await _db.collection('reels').doc(targetId).update({
            'isActive': false,
          });
        }
      }
    }
  }

  Future<bool> hasVoted(String voterUid, String reportId) async {
    final doc = await _db.collection('reportVotes').doc('${voterUid}_$reportId').get();
    return doc.exists;
  }

  Future<Map<String, dynamic>> getVoteSummary(String reportId) async {
    final reportDoc = await _db.collection('reports').doc(reportId).get();
    if (!reportDoc.exists) return {};
    final data = reportDoc.data()!;
    return {
      'validVotes': data['validVotes'] ?? 0,
      'invalidVotes': data['invalidVotes'] ?? 0,
      'totalVotes': data['totalVotes'] ?? 0,
    };
  }
}

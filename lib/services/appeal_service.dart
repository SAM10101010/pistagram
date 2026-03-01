import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class AppealService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  /// Submit an appeal
  Future<void> submitAppeal({
    required String userId,
    required String appealType,
    required String relatedId,
    required String reason,
  }) async {
    final docId = _uuid.v4();
    await _db.collection('appeals').doc(docId).set({
      'id': docId,
      'userId': userId,
      'appealType': appealType,
      'relatedId': relatedId,
      'reason': reason,
      'status': 'pending',
      'reviewedBy': null,
      'reviewedByEmail': null,
      'reviewNotes': null,
      'createdAt': Timestamp.now(),
      'reviewedAt': null,
    });
  }

  /// Get user's appeals
  Future<List<Map<String, dynamic>>> getMyAppeals(String uid) async {
    final snapshot = await _db
        .collection('appeals')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((d) {
      final data = d.data();
      data['docId'] = d.id;
      return data;
    }).toList();
  }

  /// Check if an appeal already exists for a given related item
  Future<bool> hasExistingAppeal(String relatedId) async {
    final snapshot = await _db
        .collection('appeals')
        .where('relatedId', isEqualTo: relatedId)
        .where('status', whereIn: ['pending', 'under_review'])
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }
}

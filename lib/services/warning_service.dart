import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/warning_model.dart';

class WarningService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Get active warnings for the current user
  Future<List<WarningModel>> getActiveWarnings(String uid) async {
    final snapshot = await _db
        .collection('warnings')
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((d) => WarningModel.fromMap(d.data()))
        .toList();
  }

  /// Get all warnings for the current user
  Future<List<WarningModel>> getAllWarnings(String uid) async {
    final snapshot = await _db
        .collection('warnings')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((d) => WarningModel.fromMap(d.data()))
        .toList();
  }

  /// Acknowledge a warning
  Future<void> acknowledgeWarning(String warningId) async {
    await _db.collection('warnings').doc(warningId).update({
      'acknowledgedByUser': true,
      'acknowledgedAt': Timestamp.now(),
      'status': 'acknowledged',
    });
  }

  /// Get unacknowledged warning count
  Future<int> getUnacknowledgedCount(String uid) async {
    final snapshot = await _db
        .collection('warnings')
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .where('acknowledgedByUser', isEqualTo: false)
        .count()
        .get();
    return snapshot.count ?? 0;
  }
}

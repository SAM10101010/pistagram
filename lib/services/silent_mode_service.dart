import 'package:cloud_firestore/cloud_firestore.dart';

class SilentModeService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> toggleSilentMode(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return;

    final current = doc.data()?['silentModeEnabled'] as bool? ?? false;
    await _firestore.collection('users').doc(userId).update({
      'silentModeEnabled': !current,
    });
  }

  Future<bool> isSilentModeEnabled(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return false;
    return doc.data()?['silentModeEnabled'] as bool? ?? false;
  }
}

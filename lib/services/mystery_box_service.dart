import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class MysteryBoxService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static const int boxCost = 50;
  static const int maxBoxesPerDay = 3;

  /// Opens a mystery box via Cloud Function.
  /// Returns the result map or null on failure.
  Future<Map<String, dynamic>?> openBox(String uid) async {
    try {
      final callable = _functions.httpsCallable('openMysteryBox');
      final result = await callable.call({'uid': uid});
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      return null;
    }
  }

  Future<bool> canOpenBox(String uid) async {
    // Check balance
    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists) return false;
    final balance = userDoc.data()?['pointsBalance'] ?? 0;
    if (balance < boxCost) return false;

    // Check daily limit
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final snap = await _db
        .collection('mysteryBoxResults')
        .where('uid', isEqualTo: uid)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .get();
    return snap.docs.length < maxBoxesPerDay;
  }

  Future<List<Map<String, dynamic>>> getHistory(String uid) async {
    final snap = await _db
        .collection('mysteryBoxResults')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }
}

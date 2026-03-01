import 'package:cloud_firestore/cloud_firestore.dart';

class ShadowVisibilityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> isUserShadowBanned(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['shadowBanned'] ?? false;
  }

  Future<bool> isReelShadowLimited(String reelId) async {
    final doc = await _db.collection('reels').doc(reelId).get();
    return doc.data()?['shadowLimited'] ?? false;
  }

  Future<double> getReelVisibility(String reelId) async {
    final doc = await _db.collection('reels').doc(reelId).get();
    return (doc.data()?['visibilityMultiplier'] ?? 1.0).toDouble();
  }
}

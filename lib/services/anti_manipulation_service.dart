import 'package:cloud_firestore/cloud_firestore.dart';

class AntiManipulationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> checkForManipulation(String uid) async {
    final alerts = <String>[];
    bool restricted = false;

    // Check for mass follow behavior
    final recentFollows = await _db.collection('follows')
        .where('followerId', isEqualTo: uid)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 1))))
        .get();
    if (recentFollows.docs.length > 30) {
      alerts.add('Mass follow behavior detected');
      restricted = true;
    }

    // Check for engagement spikes
    final recentLikes = await _db.collection('likes')
        .where('uid', isEqualTo: uid)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 1))))
        .get();
    if (recentLikes.docs.length > 50) {
      alerts.add('Unusual engagement spike detected');
      restricted = true;
    }

    if (restricted) {
      await _db.collection('users').doc(uid).update({
        'accountStatus': 'restricted',
      });
      await _db.collection('manipulationAlerts').add({
        'uid': uid,
        'alerts': alerts,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'status': 'active',
      });
    }

    return {
      'alerts': alerts,
      'restricted': restricted,
    };
  }

  Future<bool> isRestricted(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['accountStatus'] == 'restricted';
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class BehaviorProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String classifyBehavior(Map<String, dynamic> profile) {
    final avgWatch = (profile['avgWatchDuration'] ?? 0.0) as double;
    final commentRate = (profile['commentRate'] ?? 0.0) as double;
    final scrollSpeed = (profile['scrollSpeed'] ?? 0.0) as double;

    if (avgWatch > 80 && commentRate < 5) return 'Deep Watcher';
    if (scrollSpeed > 70) return 'Fast Scroller';
    if (commentRate > 20) return 'Discussion Leader';
    return 'Silent Viewer';
  }

  Future<Map<String, dynamic>> updateBehaviorProfile(String uid) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists) return {};
    final data = userDoc.data()!;

    final totalWatched = (data['totalWatchedReels'] ?? 0) as int;
    final commentSnap = await _db.collection('comments')
        .where('uid', isEqualTo: uid).count().get();
    final commentCount = commentSnap.count ?? 0;

    double commentRate = totalWatched > 0
        ? (commentCount / totalWatched) * 100
        : 0;

    final profile = {
      'avgWatchDuration': (data['behaviorProfile']?['avgWatchDuration'] ?? 50.0).toDouble(),
      'commentRate': commentRate,
      'scrollSpeed': (data['behaviorProfile']?['scrollSpeed'] ?? 50.0).toDouble(),
      'totalWatched': totalWatched,
      'totalComments': commentCount,
    };

    final behaviorType = classifyBehavior(profile);
    profile['behaviorType'] = behaviorType;

    await _db.collection('users').doc(uid).update({
      'behaviorProfile': profile,
    });

    return profile;
  }

  Future<String> getBehaviorType(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return 'Silent Viewer';
    final profile = doc.data()?['behaviorProfile'] ?? {};
    return profile['behaviorType'] ?? classifyBehavior(Map<String, dynamic>.from(profile));
  }
}

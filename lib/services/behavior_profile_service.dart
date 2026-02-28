import 'package:cloud_firestore/cloud_firestore.dart';

class BehaviorProfileService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> logWatchEvent(String userId, String reelId, double watchPercentage, int durationSeconds) async {
    final userRef = _firestore.collection('users').doc(userId);
    final userDoc = await userRef.get();
    if (!userDoc.exists) return;

    final profile = Map<String, dynamic>.from(userDoc.data()?['behaviorProfile'] ?? {});

    final totalWatched = (profile['totalWatched'] as int? ?? 0) + 1;
    final totalWatchPercent = (profile['totalWatchPercent'] as num? ?? 0.0).toDouble() + watchPercentage;
    final avgWatchPercent = totalWatchPercent / totalWatched;
    final deepWatches = (profile['deepWatches'] as int? ?? 0) + (watchPercentage >= 0.9 ? 1 : 0);

    profile['totalWatched'] = totalWatched;
    profile['totalWatchPercent'] = totalWatchPercent;
    profile['avgWatchPercent'] = avgWatchPercent;
    profile['deepWatches'] = deepWatches;
    profile['lastUpdated'] = Timestamp.now();

    await userRef.update({'behaviorProfile': profile});
  }

  Future<void> logScrollEvent(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);

    await _firestore.runTransaction((txn) async {
      final doc = await txn.get(userRef);
      if (!doc.exists) return;

      final profile = Map<String, dynamic>.from(doc.data()?['behaviorProfile'] ?? {});
      profile['fastScrolls'] = (profile['fastScrolls'] as int? ?? 0) + 1;
      profile['lastUpdated'] = Timestamp.now();

      txn.update(userRef, {'behaviorProfile': profile});
    });
  }

  Future<void> logCommentEvent(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);

    await _firestore.runTransaction((txn) async {
      final doc = await txn.get(userRef);
      if (!doc.exists) return;

      final profile = Map<String, dynamic>.from(doc.data()?['behaviorProfile'] ?? {});
      profile['commentsPosted'] = (profile['commentsPosted'] as int? ?? 0) + 1;
      profile['lastUpdated'] = Timestamp.now();

      txn.update(userRef, {'behaviorProfile': profile});
    });
  }

  Future<String> recalculateProfile(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);
    final doc = await userRef.get();
    if (!doc.exists) return 'silent_viewer';

    final profile = Map<String, dynamic>.from(doc.data()?['behaviorProfile'] ?? {});
    final type = getPersonalityType(profile);

    profile['personalityType'] = type;
    await userRef.update({'behaviorProfile': profile});
    return type;
  }

  String getPersonalityType(Map<String, dynamic> profile) {
    final totalWatched = (profile['totalWatched'] as int? ?? 0);
    final avgWatch = (profile['avgWatchPercent'] as num? ?? 0.0).toDouble();
    final fastScrolls = (profile['fastScrolls'] as int? ?? 0);
    final commentsPosted = (profile['commentsPosted'] as int? ?? 0);
    final deepWatches = (profile['deepWatches'] as int? ?? 0);

    if (totalWatched == 0) return 'silent_viewer';

    final scrollRatio = totalWatched > 0 ? fastScrolls / totalWatched : 0.0;
    final commentRatio = totalWatched > 0 ? commentsPosted / totalWatched : 0.0;
    final deepWatchRatio = totalWatched > 0 ? deepWatches / totalWatched : 0.0;

    if (scrollRatio > 0.5) return 'fast_scroller';
    if (deepWatchRatio > 0.4 || avgWatch > 0.8) return 'deep_watcher';
    if (commentRatio > 0.2) return 'commenter';
    return 'silent_viewer';
  }

  String getPersonalityDescription(String type) {
    switch (type) {
      case 'fast_scroller':
        return 'Quick browser who skims through content rapidly';
      case 'deep_watcher':
        return 'Engaged viewer who watches content thoroughly';
      case 'commenter':
        return 'Active participant who loves sharing thoughts';
      case 'silent_viewer':
        return 'Quiet observer who prefers watching silently';
      default:
        return 'Getting to know your viewing style...';
    }
  }

  String getPersonalityIcon(String type) {
    switch (type) {
      case 'fast_scroller':
        return 'speed';
      case 'deep_watcher':
        return 'visibility';
      case 'commenter':
        return 'chat_bubble';
      case 'silent_viewer':
        return 'visibility_off';
      default:
        return 'person';
    }
  }
}

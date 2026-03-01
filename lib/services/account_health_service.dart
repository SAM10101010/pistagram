import 'package:cloud_firestore/cloud_firestore.dart';

class AccountHealthService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Calculate composite health score from multiple components.
  /// Returns full breakdown map.
  Future<Map<String, dynamic>> calculateHealthScore(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) {
      return {'healthScore': 75.0, 'healthLevel': 'green'};
    }

    final data = doc.data()!;

    // Check if admin locked the health score
    if (data['healthLockedByAdmin'] == true) {
      return {
        'healthScore': (data['healthScore'] ?? 75.0).toDouble(),
        'healthLevel': data['healthLevel'] ?? 'green',
        'locked': true,
      };
    }

    // Component 1: Trust Score (40% weight)
    final trustScore = (data['trustScore'] ?? 50.0).toDouble();
    final trustComponent = trustScore * 0.40;

    // Component 2: Report History (20% weight)
    final reportsFiled = (data['reportsFiled'] ?? 0) as int;
    final validReportsFiled = (data['validReportsFiled'] ?? 0) as int;
    final reportsReceived = (data['reportsReceived'] ?? 0) as int;
    double reportComponent;
    if (reportsFiled == 0 && reportsReceived == 0) {
      reportComponent = 70.0 * 0.20; // neutral
    } else {
      final accuracy = reportsFiled > 0 ? validReportsFiled / reportsFiled : 0.5;
      final penalty = (reportsReceived * 5.0).clamp(0.0, 50.0);
      reportComponent = ((accuracy * 100) - penalty).clamp(0.0, 100.0) * 0.20;
    }

    // Component 3: Comment Behavior (15% weight)
    final behaviorProfile = Map<String, dynamic>.from(data['behaviorProfile'] ?? {});
    final behaviorType = behaviorProfile['behaviorType'] ?? 'silent_viewer';
    double commentBehaviorScore;
    switch (behaviorType) {
      case 'discussion_leader':
        commentBehaviorScore = 90.0;
        break;
      case 'deep_watcher':
        commentBehaviorScore = 75.0;
        break;
      case 'silent_viewer':
        commentBehaviorScore = 60.0;
        break;
      case 'fast_scroller':
        commentBehaviorScore = 40.0;
        break;
      default:
        commentBehaviorScore = 60.0;
    }
    final commentComponent = commentBehaviorScore * 0.15;

    // Component 4: Spam Activity (15% weight)
    final spamFlags = (data['spamDetectionFlags'] ?? 0) as int;
    final spamScore = (100.0 - (spamFlags * 15.0)).clamp(0.0, 100.0);
    final spamComponent = spamScore * 0.15;

    // Component 5: Violation History (10% weight)
    final violationCount = (data['violationCount'] ?? 0) as int;
    final violationScore = (100.0 - (violationCount * 20.0)).clamp(0.0, 100.0);
    final violationComponent = violationScore * 0.10;

    final totalScore = (trustComponent +
            reportComponent +
            commentComponent +
            spamComponent +
            violationComponent)
        .clamp(0.0, 100.0);

    final level = getHealthLevel(totalScore);

    return {
      'healthScore': totalScore,
      'healthLevel': level,
      'trustComponent': trustComponent,
      'reportComponent': reportComponent,
      'commentComponent': commentComponent,
      'spamComponent': spamComponent,
      'violationComponent': violationComponent,
      'trustScoreRaw': trustScore,
      'reportAccuracy': reportsFiled > 0 ? validReportsFiled / reportsFiled : 0.5,
      'reportsReceived': reportsReceived,
      'spamFlags': spamFlags,
      'violationCount': violationCount,
      'locked': false,
    };
  }

  /// Get full health breakdown for a user
  Future<Map<String, dynamic>> getHealthBreakdown(String uid) async {
    return await calculateHealthScore(uid);
  }

  /// Get health history timeline
  Future<List<Map<String, dynamic>>> getHealthHistory(String uid,
      {int limit = 20}) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('healthHistory')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }

  /// Recalculate and persist health score to the user document.
  /// Logs change to healthHistory if score changed.
  Future<void> recalculateAndStore(String uid,
      {String component = 'system', String reason = 'Automatic recalculation'}) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return;

    // Skip if admin locked
    if (doc.data()?['healthLockedByAdmin'] == true) return;

    final oldScore = (doc.data()?['healthScore'] ?? 75.0).toDouble();
    final breakdown = await calculateHealthScore(uid);
    final newScore = (breakdown['healthScore'] as double);
    final newLevel = breakdown['healthLevel'] as String;

    // Update user document
    await _db.collection('users').doc(uid).update({
      'healthScore': newScore,
      'healthLevel': newLevel,
    });

    // Log to history if score changed significantly (>0.5 difference)
    if ((newScore - oldScore).abs() > 0.5) {
      await _db
          .collection('users')
          .doc(uid)
          .collection('healthHistory')
          .add({
        'oldScore': oldScore,
        'newScore': newScore,
        'component': component,
        'reason': reason,
        'timestamp': Timestamp.now(),
      });
    }
  }

  /// Determine health level from score
  String getHealthLevel(double score) {
    if (score >= 70) return 'green';
    if (score >= 40) return 'yellow';
    return 'red';
  }

  /// Get feature limits based on health score
  Map<String, dynamic> getFeatureLimits(double score) {
    if (score >= 70) {
      return {
        'commentLimit': -1, // unlimited
        'reachReduction': 0.0,
        'canPost': true,
        'canFollow': true,
        'canMessage': true,
      };
    } else if (score >= 40) {
      return {
        'commentLimit': 20, // per hour
        'reachReduction': 0.3,
        'canPost': true,
        'canFollow': true,
        'canMessage': true,
      };
    } else {
      return {
        'commentLimit': 5, // per hour
        'reachReduction': 0.7,
        'canPost': true,
        'canFollow': true,
        'canMessage': true,
      };
    }
  }
}

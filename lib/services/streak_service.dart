import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/notification_model.dart';
import '../models/transaction_model.dart';
import 'firestore_service.dart';

class StreakService {
  final FirestoreService _firestore = FirestoreService();
  static const _uuid = Uuid();

  static const int reelsPerDay = 5;

  static const Map<int, int> streakRewards = {
    1: 5,
    3: 20,
    7: 50,
    14: 100,
    30: 200,
  };

  /// Call when a user completes watching a reel.
  /// Returns a map with streak info if a milestone was hit, null otherwise.
  Future<Map<String, dynamic>?> onReelCompleted(String uid) async {
    final user = await _firestore.getUser(uid);
    if (user == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = user.lastStreakDate;
    final lastDay = lastDate != null
        ? DateTime(lastDate.year, lastDate.month, lastDate.day)
        : null;

    int streakCount = user.streakCount;
    int reelsToday = user.streakReelsToday;

    if (lastDay == null || today.difference(lastDay).inDays > 1) {
      // Streak broken or first time
      streakCount = 0;
      reelsToday = 1;
    } else if (today.difference(lastDay).inDays == 1) {
      // New day, continuing streak (only if yesterday hit threshold)
      if (user.streakReelsToday >= reelsPerDay) {
        // Yesterday was a valid streak day, keep going
        reelsToday = 1;
      } else {
        // Yesterday didn't hit threshold, streak resets
        streakCount = 0;
        reelsToday = 1;
      }
    } else if (today == lastDay) {
      // Same day
      reelsToday = user.streakReelsToday + 1;
    }

    Map<String, dynamic>? milestoneInfo;

    // Check if we just hit the daily threshold
    if (reelsToday == reelsPerDay &&
        (lastDay == null ||
            today != lastDay ||
            user.streakReelsToday < reelsPerDay)) {
      streakCount += 1;

      // Check milestone
      if (streakRewards.containsKey(streakCount)) {
        final bonus = streakRewards[streakCount]!;
        // Award bonus points directly to available balance
        final txn = TransactionModel(
          id: _uuid.v4(),
          uid: uid,
          type: 'bonus',
          amount: bonus,
          reason: 'Streak Day $streakCount bonus',
        );
        await _firestore.addTransaction(txn);
        await _firestore.updatePointsBalance(uid, bonus);
        milestoneInfo = {
          'streakCount': streakCount,
          'bonusPoints': bonus,
          'isMilestone': true,
        };

        // Notification
        await _firestore.addNotification(
          NotificationModel(
            id: _uuid.v4(),
            toUid: uid,
            fromUid: uid,
            type: 'streak',
            message: '$streakCount-day streak! You earned $bonus bonus points!',
          ),
        );
      } else {
        milestoneInfo = {
          'streakCount': streakCount,
          'bonusPoints': 0,
          'isMilestone': false,
        };
      }
    }

    await _firestore.updateUser(uid, {
      'streakCount': streakCount,
      'streakReelsToday': reelsToday,
      'lastStreakDate': Timestamp.fromDate(now),
      'totalWatchedReels': FieldValue.increment(1),
    });

    return milestoneInfo;
  }

  Future<Map<String, dynamic>> getStreakInfo(String uid) async {
    final user = await _firestore.getUser(uid);
    if (user == null) {
      return {
        'streakCount': 0,
        'reelsToday': 0,
        'nextMilestone': 1,
        'nextReward': 5,
      };
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = user.lastStreakDate;
    final lastDay = lastDate != null
        ? DateTime(lastDate.year, lastDate.month, lastDate.day)
        : null;

    int streakCount = user.streakCount;
    int reelsToday = user.streakReelsToday;

    // Check if streak is still active
    if (lastDay != null && today.difference(lastDay).inDays > 1) {
      streakCount = 0;
      reelsToday = 0;
    } else if (lastDay != null &&
        today.difference(lastDay).inDays == 1 &&
        user.streakReelsToday < reelsPerDay) {
      streakCount = 0;
      reelsToday = 0;
    }

    // Find next milestone
    int nextMilestone = 1;
    int nextReward = 5;
    for (final entry in streakRewards.entries) {
      if (entry.key > streakCount) {
        nextMilestone = entry.key;
        nextReward = entry.value;
        break;
      }
    }

    return {
      'streakCount': streakCount,
      'reelsToday': reelsToday,
      'reelsNeeded': reelsPerDay,
      'nextMilestone': nextMilestone,
      'nextReward': nextReward,
    };
  }
}

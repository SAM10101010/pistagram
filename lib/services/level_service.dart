import 'package:uuid/uuid.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class LevelService {
  final FirestoreService _firestore = FirestoreService();
  static const _uuid = Uuid();

  static const levelThresholds = {
    'beginner': 0,
    'active': 100,
    'pro': 500,
    'elite': 1500,
  };

  static Map<String, dynamic> getLevelInfo(String level) {
    switch (level) {
      case 'elite':
        return {
          'name': 'Elite Viewer',
          'minPoints': 1500,
          'color': 0xFFFFD700,
          'icon': 'diamond',
        };
      case 'pro':
        return {
          'name': 'Pro Watcher',
          'minPoints': 500,
          'color': 0xFF9C27B0,
          'icon': 'star',
        };
      case 'active':
        return {
          'name': 'Active Viewer',
          'minPoints': 100,
          'color': 0xFF2196F3,
          'icon': 'trending_up',
        };
      default:
        return {
          'name': 'Beginner',
          'minPoints': 0,
          'color': 0xFF9E9E9E,
          'icon': 'person',
        };
    }
  }

  static double getNextLevelProgress(int totalPoints) {
    if (totalPoints >= 1500) return 1.0;
    if (totalPoints >= 500) return (totalPoints - 500) / 1000;
    if (totalPoints >= 100) return (totalPoints - 100) / 400;
    return totalPoints / 100;
  }

  static int getNextLevelThreshold(int totalPoints) {
    if (totalPoints >= 1500) return 1500;
    if (totalPoints >= 500) return 1500;
    if (totalPoints >= 100) return 500;
    return 100;
  }

  /// Increment lifetime points and recalculate level.
  /// Returns the new level if it changed, null otherwise.
  Future<String?> addEarnedPoints(String uid, int amount) async {
    final user = await _firestore.getUser(uid);
    if (user == null) return null;

    final oldLevel = user.viewerLevel;
    final newTotal = user.totalPointsEarned + amount;
    final newLevel = UserModel.calculateLevel(newTotal);

    final updates = <String, dynamic>{'totalPointsEarned': newTotal};

    if (newLevel != oldLevel) {
      updates['viewerLevel'] = newLevel;
      await _firestore.updateUser(uid, updates);

      // Send level-up notification
      final levelInfo = getLevelInfo(newLevel);
      await _firestore.addNotification(
        NotificationModel(
          id: _uuid.v4(),
          toUid: uid,
          fromUid: uid,
          type: 'level_up',
          message: 'You reached ${levelInfo['name']}!',
        ),
      );
      return newLevel;
    }

    await _firestore.updateUser(uid, updates);
    return null;
  }
}

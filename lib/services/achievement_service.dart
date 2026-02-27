import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/notification_model.dart';
import 'firestore_service.dart';

class AchievementService {
  final FirestoreService _firestore = FirestoreService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _achievements =>
      _db.collection('userAchievements');

  static const List<Map<String, String>> allAchievements = [
    // Watching
    {
      'id': 'first_watch',
      'title': 'First Steps',
      'desc': 'Watch your first reel',
      'icon': 'play_arrow',
      'category': 'watching',
    },
    {
      'id': 'watch_50',
      'title': 'Curious Viewer',
      'desc': 'Watch 50 reels',
      'icon': 'visibility',
      'category': 'watching',
    },
    {
      'id': 'watch_100',
      'title': 'Dedicated Viewer',
      'desc': 'Watch 100 reels',
      'icon': 'local_fire_department',
      'category': 'watching',
    },
    {
      'id': 'watch_500',
      'title': 'Reel Addict',
      'desc': 'Watch 500 reels',
      'icon': 'whatshot',
      'category': 'watching',
    },
    // Streaks
    {
      'id': 'streak_3',
      'title': 'Getting Warm',
      'desc': '3-day watch streak',
      'icon': 'whatshot',
      'category': 'streak',
    },
    {
      'id': 'streak_7',
      'title': 'On Fire',
      'desc': '7-day watch streak',
      'icon': 'local_fire_department',
      'category': 'streak',
    },
    {
      'id': 'streak_30',
      'title': 'Unstoppable',
      'desc': '30-day watch streak',
      'icon': 'bolt',
      'category': 'streak',
    },
    // Social
    {
      'id': 'first_like',
      'title': 'Appreciator',
      'desc': 'Like your first reel',
      'icon': 'favorite',
      'category': 'social',
    },
    {
      'id': 'first_comment',
      'title': 'Conversationalist',
      'desc': 'Post your first comment',
      'icon': 'chat_bubble',
      'category': 'social',
    },
    // Spending
    {
      'id': 'first_redeem',
      'title': 'Smart Shopper',
      'desc': 'Redeem your first reward',
      'icon': 'shopping_bag',
      'category': 'spending',
    },
    // Levels
    {
      'id': 'level_active',
      'title': 'Level Up!',
      'desc': 'Reach Active Viewer level',
      'icon': 'trending_up',
      'category': 'watching',
    },
    {
      'id': 'level_pro',
      'title': 'Pro Status',
      'desc': 'Reach Pro Watcher level',
      'icon': 'star',
      'category': 'watching',
    },
    {
      'id': 'level_elite',
      'title': 'Elite Club',
      'desc': 'Reach Elite Viewer level',
      'icon': 'diamond',
      'category': 'watching',
    },
  ];

  /// Check and award achievements based on trigger type.
  /// Returns list of newly earned achievement titles for popup display.
  Future<List<Map<String, String>>> checkAndAward(
    String uid,
    String triggerType, {
    Map<String, dynamic>? context,
  }) async {
    final user = await _firestore.getUser(uid);
    if (user == null) return [];

    final earned = <Map<String, String>>[];
    final checks = <String, bool>{};

    switch (triggerType) {
      case 'watch':
        final total = user.totalWatchedReels;
        checks['first_watch'] = total >= 1;
        checks['watch_50'] = total >= 50;
        checks['watch_100'] = total >= 100;
        checks['watch_500'] = total >= 500;
        break;
      case 'streak':
        final streak = context?['streakCount'] as int? ?? user.streakCount;
        checks['streak_3'] = streak >= 3;
        checks['streak_7'] = streak >= 7;
        checks['streak_30'] = streak >= 30;
        break;
      case 'like':
        checks['first_like'] = true; // If triggered, they must have liked
        break;
      case 'comment':
        checks['first_comment'] = true;
        break;
      case 'redeem':
        checks['first_redeem'] = true;
        break;
      case 'levelup':
        final level = context?['level'] as String? ?? user.viewerLevel;
        checks['level_active'] =
            level == 'active' || level == 'pro' || level == 'elite';
        checks['level_pro'] = level == 'pro' || level == 'elite';
        checks['level_elite'] = level == 'elite';
        break;
    }

    for (final entry in checks.entries) {
      if (!entry.value) continue;

      final docId = '${uid}_${entry.key}';
      final existing = await _achievements.doc(docId).get();
      if (existing.exists) continue;

      final achievement = allAchievements.firstWhere(
        (a) => a['id'] == entry.key,
        orElse: () => {},
      );
      if (achievement.isEmpty) continue;

      await _achievements.doc(docId).set({
        'uid': uid,
        'achievementId': entry.key,
        'title': achievement['title'],
        'description': achievement['desc'],
        'icon': achievement['icon'],
        'category': achievement['category'],
        'earnedAt': Timestamp.fromDate(DateTime.now()),
      });

      earned.add(achievement);

      await _firestore.addNotification(
        NotificationModel(
          id: _uuid.v4(),
          toUid: uid,
          fromUid: uid,
          type: 'achievement',
          message: 'Achievement unlocked: ${achievement['title']}!',
        ),
      );
    }

    return earned;
  }

  Future<List<Map<String, dynamic>>> getUserAchievements(String uid) async {
    final snap = await _achievements
        .where('uid', isEqualTo: uid)
        .orderBy('earnedAt', descending: true)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<Map<String, dynamic>> getAchievementProgress(String uid) async {
    final earned = await getUserAchievements(uid);
    return {
      'earned': earned.length,
      'total': allAchievements.length,
      'earnedIds': earned.map((a) => a['achievementId']).toList(),
    };
  }
}

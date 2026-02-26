import '../models/notification_model.dart';
import 'firestore_service.dart';

class NotificationService {
  final FirestoreService _firestoreService = FirestoreService();

  /// Get notifications — filtered by user's mute settings
  Future<List<NotificationModel>> getFilteredNotifications(String uid) async {
    final user = await _firestoreService.getUser(uid);
    final muteLikes = user?.privacySettings['muteLikes'] ?? false;
    final muteComments = user?.privacySettings['muteComments'] ?? false;
    final mutePoints = user?.privacySettings['mutePoints'] ?? false;

    // Get raw notifications stream and convert to list
    final allNotifications = await _firestoreService.getNotifications(uid).first;

    return allNotifications.where((n) {
      if (muteLikes && n.type == 'like') return false;
      if (muteComments && (n.type == 'comment' || n.type == 'reply')) return false;
      if (mutePoints && (n.type == 'points_earned' || n.type == 'reward_redeemed')) return false;
      return true;
    }).toList();
  }

  Stream<List<NotificationModel>> getNotifications(String uid) {
    return _firestoreService.getNotifications(uid);
  }

  Stream<int> getUnreadCount(String uid) {
    return _firestoreService.getUnreadNotificationCount(uid);
  }

  Future<void> markAsRead(String id) async {
    await _firestoreService.markNotificationRead(id);
  }

  Future<void> markAllAsRead(String uid) async {
    await _firestoreService.markAllNotificationsRead(uid);
  }

  /// Update notification preferences
  Future<void> updateNotificationSettings(String uid, {
    bool? muteLikes,
    bool? muteComments,
    bool? mutePoints,
  }) async {
    final user = await _firestoreService.getUser(uid);
    if (user == null) return;

    final settings = Map<String, dynamic>.from(user.privacySettings);
    if (muteLikes != null) settings['muteLikes'] = muteLikes;
    if (muteComments != null) settings['muteComments'] = muteComments;
    if (mutePoints != null) settings['mutePoints'] = mutePoints;

    await _firestoreService.updateUser(uid, {'privacySettings': settings});
  }
}

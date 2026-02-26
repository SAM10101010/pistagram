import 'package:uuid/uuid.dart';
import '../models/follow_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class FollowService {
  final FirestoreService _firestoreService = FirestoreService();
  final _uuid = const Uuid();

  Future<void> followUser(String currentUid, String targetUid) async {
    // Check if blocked
    if (await _firestoreService.isBlockedByEither(currentUid, targetUid)) {
      throw Exception('Cannot follow this user');
    }

    // Check target account type
    final targetUser = await _firestoreService.getUser(targetUid);
    if (targetUser == null) throw Exception('User not found');

    final status = targetUser.accountType == 'private' ? 'pending' : 'accepted';

    final follow = FollowModel(
      followerId: currentUid,
      followingId: targetUid,
      status: status,
    );

    await _firestoreService.createFollow(follow);

    if (status == 'accepted') {
      await _firestoreService.incrementFollowers(targetUid);
      await _firestoreService.incrementFollowing(currentUid);
    }

    // Create notification
    await _firestoreService.addNotification(NotificationModel(
      id: _uuid.v4(),
      toUid: targetUid,
      fromUid: currentUid,
      type: status == 'pending' ? 'follow_request' : 'follow',
      message: status == 'pending' ? 'sent you a follow request' : 'started following you',
    ));
  }

  Future<void> unfollowUser(String currentUid, String targetUid) async {
    final existing = await _firestoreService.getFollow(currentUid, targetUid);
    if (existing == null) return;

    await _firestoreService.deleteFollow(currentUid, targetUid);
    if (existing.status == 'accepted') {
      await _firestoreService.decrementFollowers(targetUid);
      await _firestoreService.decrementFollowing(currentUid);
    }
  }

  Future<void> acceptRequest(String followerId, String followingId) async {
    await _firestoreService.updateFollowStatus(followerId, followingId, 'accepted');
    await _firestoreService.incrementFollowers(followingId);
    await _firestoreService.incrementFollowing(followerId);

    await _firestoreService.addNotification(NotificationModel(
      id: _uuid.v4(),
      toUid: followerId,
      fromUid: followingId,
      type: 'follow',
      message: 'accepted your follow request',
    ));
  }

  Future<void> rejectRequest(String followerId, String followingId) async {
    await _firestoreService.deleteFollow(followerId, followingId);
  }

  Future<void> removeFollower(String uid, String followerUid) async {
    await _firestoreService.deleteFollow(followerUid, uid);
    await _firestoreService.decrementFollowers(uid);
    await _firestoreService.decrementFollowing(followerUid);
  }

  Future<void> blockUser(String blockerUid, String blockedUid) async {
    await _firestoreService.blockUser(blockerUid, blockedUid);
    // Also unfollow both ways
    await unfollowUser(blockerUid, blockedUid);
    await unfollowUser(blockedUid, blockerUid);
  }

  Future<void> unblockUser(String blockerUid, String blockedUid) async {
    await _firestoreService.unblockUser(blockerUid, blockedUid);
  }

  Future<List<UserModel>> getFollowers(String uid) async {
    final follows = await _firestoreService.getFollowers(uid);
    final users = <UserModel>[];
    for (final f in follows) {
      final user = await _firestoreService.getUser(f.followerId);
      if (user != null) users.add(user);
    }
    return users;
  }

  Future<List<UserModel>> getFollowing(String uid) async {
    final follows = await _firestoreService.getFollowing(uid);
    final users = <UserModel>[];
    for (final f in follows) {
      final user = await _firestoreService.getUser(f.followingId);
      if (user != null) users.add(user);
    }
    return users;
  }

  Future<List<FollowModel>> getPendingRequests(String uid) async {
    return await _firestoreService.getPendingRequests(uid);
  }

  Future<String> getRelationship(String currentUid, String targetUid) async {
    final follow = await _firestoreService.getFollow(currentUid, targetUid);
    if (follow == null) return 'none';
    return follow.status;
  }

  Future<bool> isFollowing(String currentUid, String targetUid) async {
    final follow = await _firestoreService.getFollow(currentUid, targetUid);
    return follow != null && follow.status == 'accepted';
  }
}

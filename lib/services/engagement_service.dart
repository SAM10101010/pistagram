import 'package:uuid/uuid.dart';
import '../models/comment_model.dart';
import '../models/notification_model.dart';
import 'firestore_service.dart';

class EngagementService {
  final FirestoreService _firestoreService = FirestoreService();
  final _uuid = const Uuid();

  // ── Likes ──
  Future<void> likeReel(String uid, String reelId, String creatorUid) async {
    // Block check
    if (await _firestoreService.isBlockedByEither(uid, creatorUid)) return;

    // Check reel visibility — if private, only creator can see
    final reel = await _firestoreService.getReel(reelId);
    if (reel == null) return;
    if (reel.visibility == 'private' && reel.creatorUid != uid) return;

    // If followers-only, check follow status
    if (reel.visibility == 'followers') {
      final follow = await _firestoreService.getFollow(uid, creatorUid);
      if (follow == null || follow.status != 'accepted') return;
    }

    await _firestoreService.likeReel(uid, reelId);
    await _firestoreService.incrementTotalLikes(creatorUid);

    if (uid != creatorUid) {
      // Check notification settings — respect mute
      final creator = await _firestoreService.getUser(creatorUid);
      final muteLikes = creator?.privacySettings['muteLikes'] ?? false;
      if (!muteLikes) {
        await _firestoreService.addNotification(NotificationModel(
          id: _uuid.v4(),
          toUid: creatorUid,
          fromUid: uid,
          type: 'like',
          reelId: reelId,
          message: 'liked your reel',
        ));
      }
    }
  }

  Future<void> unlikeReel(String uid, String reelId, String creatorUid) async {
    await _firestoreService.unlikeReel(uid, reelId);
    await _firestoreService.decrementTotalLikes(creatorUid);
  }

  Future<bool> hasLiked(String uid, String reelId) async {
    return await _firestoreService.hasLikedReel(uid, reelId);
  }

  // ── Comments ──
  Future<CommentModel> addComment({
    required String reelId,
    required String uid,
    required String text,
    required String creatorUid,
    String parentId = '',
  }) async {
    // Block check
    if (await _firestoreService.isBlockedByEither(uid, creatorUid)) {
      throw Exception('Cannot comment on this reel');
    }

    // Private account restriction: only followers can comment
    final reelOwner = await _firestoreService.getUser(creatorUid);
    if (reelOwner != null && reelOwner.isPrivate && uid != creatorUid) {
      final follow = await _firestoreService.getFollow(uid, creatorUid);
      if (follow == null || follow.status != 'accepted') {
        throw Exception('Only followers can comment on this content');
      }
    }

    // Check reel visibility
    final reel = await _firestoreService.getReel(reelId);
    if (reel != null) {
      if (reel.visibility == 'private' && uid != creatorUid) {
        throw Exception('Cannot comment on private content');
      }
      if (reel.visibility == 'followers' && uid != creatorUid) {
        final follow = await _firestoreService.getFollow(uid, creatorUid);
        if (follow == null || follow.status != 'accepted') {
          throw Exception('Only followers can comment');
        }
      }
    }

    final comment = CommentModel(
      id: _uuid.v4(),
      reelId: reelId,
      uid: uid,
      text: text,
      parentId: parentId,
    );

    await _firestoreService.addComment(comment);

    if (uid != creatorUid) {
      final muteComments = reelOwner?.privacySettings['muteComments'] ?? false;
      if (!muteComments) {
        await _firestoreService.addNotification(NotificationModel(
          id: _uuid.v4(),
          toUid: creatorUid,
          fromUid: uid,
          type: 'comment',
          reelId: reelId,
          message: parentId.isEmpty ? 'commented on your reel' : 'replied to your comment',
        ));
      }
    }

    return comment;
  }

  Future<void> deleteComment(String commentId, String reelId) async {
    await _firestoreService.deleteComment(commentId, reelId);
  }

  Stream<List<CommentModel>> getComments(String reelId) {
    return _firestoreService.getComments(reelId);
  }

  Stream<List<CommentModel>> getReplies(String parentId) {
    return _firestoreService.getReplies(parentId);
  }

  // ── Saves ──
  Future<void> saveReel(String uid, String reelId) async {
    await _firestoreService.saveReel(uid, reelId);
  }

  Future<void> unsaveReel(String uid, String reelId) async {
    await _firestoreService.unsaveReel(uid, reelId);
  }

  Future<bool> hasSaved(String uid, String reelId) async {
    return await _firestoreService.hasSavedReel(uid, reelId);
  }
}

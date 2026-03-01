import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/reel_model.dart';
import '../models/post_model.dart';
import '../models/story_model.dart';
import '../models/follow_model.dart';
import '../models/transaction_model.dart';
import '../models/notification_model.dart';
import '../models/comment_model.dart';
import '../models/message_model.dart';
import '../models/reward_model.dart';
import '../models/report_model.dart';
import '../models/block_model.dart';
import '../models/story_reaction_model.dart';
import '../models/point_transfer_model.dart';
import '../models/group_chat_model.dart';
import '../models/group_message_model.dart';
import '../models/group_invite_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Collection References ──
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _reels =>
      _db.collection('reels');
  CollectionReference<Map<String, dynamic>> get _follows =>
      _db.collection('follows');
  CollectionReference<Map<String, dynamic>> get _transactions =>
      _db.collection('transactions');
  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection('notifications');
  CollectionReference<Map<String, dynamic>> get _comments =>
      _db.collection('comments');
  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');
  CollectionReference<Map<String, dynamic>> get _rewards =>
      _db.collection('rewards');
  CollectionReference<Map<String, dynamic>> get _redemptions =>
      _db.collection('redemptions');
  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('reports');
  CollectionReference<Map<String, dynamic>> get _blocks =>
      _db.collection('blocks');
  CollectionReference<Map<String, dynamic>> get _likes =>
      _db.collection('likes');
  CollectionReference<Map<String, dynamic>> get _saves =>
      _db.collection('saves');
  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');
  CollectionReference<Map<String, dynamic>> get _stories =>
      _db.collection('stories');
  CollectionReference<Map<String, dynamic>> get _storyReactions =>
      _db.collection('storyReactions');
  CollectionReference<Map<String, dynamic>> get _pointTransfers =>
      _db.collection('pointTransfers');
  CollectionReference<Map<String, dynamic>> get _vaultReels =>
      _db.collection('vaultReels');
  CollectionReference<Map<String, dynamic>> get _groupChats =>
      _db.collection('groupChats');
  CollectionReference<Map<String, dynamic>> get _groupInvitations =>
      _db.collection('groupInvitations');

  // ═══════════════════════════════════════
  // USERS
  // ═══════════════════════════════════════
  Future<void> createUser(UserModel user) async {
    await _users.doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    data['updatedAt'] = Timestamp.fromDate(DateTime.now());
    await _users.doc(uid).update(data);
  }

  Future<List<UserModel>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    final snap = await _users
        .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
        .where('username', isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
        .limit(20)
        .get();
    return snap.docs.map((d) => UserModel.fromMap(d.data())).toList();
  }

  Stream<UserModel?> userStream(String uid) {
    return _users.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserModel.fromMap(snap.data()!);
    });
  }

  // ═══════════════════════════════════════
  // REELS
  // ═══════════════════════════════════════
  Future<void> createReel(ReelModel reel) async {
    await _reels.doc(reel.reelId).set(reel.toMap());
  }

  Future<ReelModel?> getReel(String reelId) async {
    final doc = await _reels.doc(reelId).get();
    if (!doc.exists) return null;
    return ReelModel.fromMap(doc.data()!);
  }

  Future<void> updateReel(String reelId, Map<String, dynamic> data) async {
    await _reels.doc(reelId).update(data);
  }

  Future<void> deleteReel(String reelId) async {
    await _reels.doc(reelId).update({'isActive': false});
  }

  Future<List<ReelModel>> getReelsByUser(String uid) async {
    final snap = await _reels
        .where('creatorUid', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => ReelModel.fromMap(d.data())).toList();
  }

  Future<List<ReelModel>> getPublicReels({int limit = 20}) async {
    final snap = await _reels
        .where('visibility', isEqualTo: 'public')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => ReelModel.fromMap(d.data())).toList();
  }

  Future<List<ReelModel>> getFeedReels(
    List<String> followingUids, {
    int limit = 20,
  }) async {
    if (followingUids.isEmpty) return [];
    // Firestore whereIn limit is 30
    final chunks = <List<String>>[];
    for (var i = 0; i < followingUids.length; i += 30) {
      chunks.add(
        followingUids.sublist(
          i,
          i + 30 > followingUids.length ? followingUids.length : i + 30,
        ),
      );
    }
    final allReels = <ReelModel>[];
    for (final chunk in chunks) {
      final snap = await _reels
          .where('creatorUid', whereIn: chunk)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      allReels.addAll(snap.docs.map((d) => ReelModel.fromMap(d.data())));
    }
    allReels.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return allReels.take(limit).toList();
  }

  Future<List<ReelModel>> getTrendingReels({int limit = 20}) async {
    final snap = await _reels
        .where('visibility', isEqualTo: 'public')
        .where('isActive', isEqualTo: true)
        .orderBy('likesCount', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => ReelModel.fromMap(d.data())).toList();
  }

  Future<List<ReelModel>> getReelsByHashtag(
    String hashtag, {
    int limit = 20,
  }) async {
    final snap = await _reels
        .where('hashtags', arrayContains: hashtag.toLowerCase())
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => ReelModel.fromMap(d.data())).toList();
  }

  // ═══════════════════════════════════════
  // FOLLOWS
  // ═══════════════════════════════════════
  Future<void> createFollow(FollowModel follow) async {
    final docId = '${follow.followerId}_${follow.followingId}';
    await _follows.doc(docId).set(follow.toMap());
  }

  Future<void> deleteFollow(String followerId, String followingId) async {
    await _follows.doc('${followerId}_$followingId').delete();
  }

  Future<FollowModel?> getFollow(String followerId, String followingId) async {
    final doc = await _follows.doc('${followerId}_$followingId').get();
    if (!doc.exists) return null;
    return FollowModel.fromMap(doc.data()!);
  }

  Future<void> updateFollowStatus(
    String followerId,
    String followingId,
    String status,
  ) async {
    await _follows.doc('${followerId}_$followingId').update({'status': status});
  }

  Future<List<FollowModel>> getFollowers(String uid) async {
    final snap = await _follows
        .where('followingId', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .get();
    return snap.docs.map((d) => FollowModel.fromMap(d.data())).toList();
  }

  Future<List<FollowModel>> getFollowing(String uid) async {
    final snap = await _follows
        .where('followerId', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .get();
    return snap.docs.map((d) => FollowModel.fromMap(d.data())).toList();
  }

  Future<List<FollowModel>> getPendingRequests(String uid) async {
    final snap = await _follows
        .where('followingId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .get();
    return snap.docs.map((d) => FollowModel.fromMap(d.data())).toList();
  }

  Future<List<FollowModel>> getSentRequests(String uid) async {
    final snap = await _follows
        .where('followerId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .get();
    return snap.docs.map((d) => FollowModel.fromMap(d.data())).toList();
  }

  Future<List<String>> getFollowingUids(String uid) async {
    final follows = await getFollowing(uid);
    return follows.map((f) => f.followingId).toList();
  }

  // ═══════════════════════════════════════
  // LIKES
  // ═══════════════════════════════════════
  Future<void> likeReel(String uid, String reelId, {String? creatorUid}) async {
    final batch = _db.batch();
    batch.set(_likes.doc('${uid}_$reelId'), {
      'uid': uid,
      'reelId': reelId,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
    batch.update(_reels.doc(reelId), {'likesCount': FieldValue.increment(1)});
    await batch.commit();

    // Create notification for reel creator
    if (creatorUid != null && creatorUid != uid) {
      await addNotification(
        NotificationModel(
          id: '${uid}_like_$reelId',
          toUid: creatorUid,
          fromUid: uid,
          type: 'like',
          message: 'liked your reel',
          reelId: reelId,
        ),
      );
    }
  }

  Future<void> unlikeReel(String uid, String reelId) async {
    final batch = _db.batch();
    batch.delete(_likes.doc('${uid}_$reelId'));
    batch.update(_reels.doc(reelId), {'likesCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  Future<bool> hasLikedReel(String uid, String reelId) async {
    final doc = await _likes.doc('${uid}_$reelId').get();
    return doc.exists;
  }

  // ═══════════════════════════════════════
  // SAVES
  // ═══════════════════════════════════════
  Future<void> saveReel(String uid, String reelId) async {
    await _saves.doc('${uid}_$reelId').set({
      'uid': uid,
      'reelId': reelId,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> unsaveReel(String uid, String reelId) async {
    await _saves.doc('${uid}_$reelId').delete();
  }

  Future<bool> hasSavedReel(String uid, String reelId) async {
    final doc = await _saves.doc('${uid}_$reelId').get();
    return doc.exists;
  }

  Future<List<String>> getSavedReelIds(String uid) async {
    final snap = await _saves
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .where((d) => d.data()['reelId'] != null)
        .map((d) => d.data()['reelId'] as String)
        .toList();
  }

  Future<List<String>> getLikedReelIds(String uid) async {
    final snap = await _likes
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .where((d) => d.data()['reelId'] != null)
        .map((d) => d.data()['reelId'] as String)
        .toList();
  }

  Future<List<String>> getLikedPostIds(String uid) async {
    final snap = await _likes
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .where((d) => d.data()['postId'] != null)
        .map((d) => d.data()['postId'] as String)
        .toList();
  }

  // ═══════════════════════════════════════
  // COMMENTS
  // ═══════════════════════════════════════
  Future<void> addComment(CommentModel comment, {String? creatorUid}) async {
    final batch = _db.batch();
    batch.set(_comments.doc(comment.id), comment.toMap());
    batch.update(_reels.doc(comment.reelId), {
      'commentsCount': FieldValue.increment(1),
    });
    await batch.commit();

    // Create notification for reel creator
    if (creatorUid != null && creatorUid != comment.uid) {
      await addNotification(
        NotificationModel(
          id: 'comment_${comment.id}',
          toUid: creatorUid,
          fromUid: comment.uid,
          type: 'comment',
          message: 'commented on your reel',
          reelId: comment.reelId,
        ),
      );
    }
  }

  Future<void> addPostComment(
    CommentModel comment, {
    String? creatorUid,
  }) async {
    final batch = _db.batch();
    batch.set(_comments.doc(comment.id), comment.toMap());
    batch.update(_posts.doc(comment.reelId), {
      'commentsCount': FieldValue.increment(1),
    });
    await batch.commit();

    // Create notification for post creator
    if (creatorUid != null && creatorUid != comment.uid) {
      await addNotification(
        NotificationModel(
          id: 'comment_${comment.id}',
          toUid: creatorUid,
          fromUid: comment.uid,
          type: 'comment',
          message: 'commented on your post',
          postId: comment.reelId,
        ),
      );
    }
  }

  Future<void> deleteComment(String commentId, String reelId) async {
    final batch = _db.batch();
    batch.delete(_comments.doc(commentId));
    batch.update(_reels.doc(reelId), {
      'commentsCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  Future<void> deletePostComment(String commentId, String postId) async {
    final batch = _db.batch();
    batch.delete(_comments.doc(commentId));
    batch.update(_posts.doc(postId), {
      'commentsCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  Stream<List<CommentModel>> getComments(String reelId) {
    return _comments
        .where('reelId', isEqualTo: reelId)
        .where('parentId', isEqualTo: '')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => CommentModel.fromMap(d.data())).toList(),
        );
  }

  Stream<List<CommentModel>> getReplies(String parentId) {
    return _comments
        .where('parentId', isEqualTo: parentId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => CommentModel.fromMap(d.data())).toList(),
        );
  }

  Future<void> likeComment(String commentId, String uid, {String? commentOwnerUid, String? reelId, String? postId}) async {
    await _comments.doc(commentId).update({
      'likedByUids': FieldValue.arrayUnion([uid]),
      'likesCount': FieldValue.increment(1),
    });
    // Send notification to comment owner
    if (commentOwnerUid != null && commentOwnerUid != uid) {
      await addNotification(
        NotificationModel(
          id: '${uid}_comment_like_$commentId',
          toUid: commentOwnerUid,
          fromUid: uid,
          type: 'comment_like',
          message: 'liked your comment',
          commentId: commentId,
          reelId: reelId ?? '',
          postId: postId ?? '',
        ),
      );
    }
  }

  Future<void> unlikeComment(String commentId, String uid) async {
    await _comments.doc(commentId).update({
      'likedByUids': FieldValue.arrayRemove([uid]),
      'likesCount': FieldValue.increment(-1),
    });
  }

  Future<void> addReply(CommentModel reply, {String? parentCommentUid, String? contentCreatorUid}) async {
    final batch = _db.batch();
    batch.set(_comments.doc(reply.id), reply.toMap());
    // Increment parent comment's reply count
    batch.update(_comments.doc(reply.parentId), {
      'repliesCount': FieldValue.increment(1),
    });
    await batch.commit();

    // Notify parent comment author about the reply
    if (parentCommentUid != null && parentCommentUid != reply.uid) {
      await addNotification(
        NotificationModel(
          id: 'reply_${reply.id}',
          toUid: parentCommentUid,
          fromUid: reply.uid,
          type: 'comment_reply',
          message: 'replied to your comment',
          commentId: reply.parentId,
          reelId: reply.reelId,
        ),
      );
    }
  }

  // ═══════════════════════════════════════
  // TRANSACTIONS
  // ═══════════════════════════════════════
  Future<void> addTransaction(TransactionModel txn) async {
    await _transactions.doc(txn.id).set(txn.toMap());
  }

  /// Returns true if check-in was successful, false if already claimed today
  Future<bool> claimDailyCheckIn(String uid) async {
    final userDoc = _users.doc(uid);
    final snap = await userDoc.get();
    if (!snap.exists) return false;
    final data = snap.data() as Map<String, dynamic>;
    final lastCheckin = (data['lastDailyCheckin'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    if (lastCheckin != null &&
        lastCheckin.year == now.year &&
        lastCheckin.month == now.month &&
        lastCheckin.day == now.day) {
      return false; // Already claimed today
    }
    await userDoc.update({
      'lastDailyCheckin': Timestamp.fromDate(now),
      'pointsBalance': FieldValue.increment(1),
      'totalPointsEarned': FieldValue.increment(1),
    });
    final txn = TransactionModel(
      id: 'checkin_${uid}_${now.millisecondsSinceEpoch}',
      uid: uid,
      type: 'earned',
      amount: 1,
      reason: 'Daily check-in reward',
      createdAt: now,
    );
    await addTransaction(txn);
    return true;
  }

  /// Check if user already claimed daily check-in today
  Future<bool> hasClaimedDailyCheckIn(String uid) async {
    final snap = await _users.doc(uid).get();
    if (!snap.exists) return false;
    final data = snap.data() as Map<String, dynamic>;
    final lastCheckin = (data['lastDailyCheckin'] as Timestamp?)?.toDate();
    if (lastCheckin == null) return false;
    final now = DateTime.now();
    return lastCheckin.year == now.year &&
        lastCheckin.month == now.month &&
        lastCheckin.day == now.day;
  }

  Future<List<TransactionModel>> getUserTransactions(
    String uid, {
    int limit = 50,
  }) async {
    final snap = await _transactions
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => TransactionModel.fromMap(d.data())).toList();
  }

  // ═══════════════════════════════════════
  // NOTIFICATIONS
  // ═══════════════════════════════════════
  Future<void> addNotification(NotificationModel notif) async {
    await _notifications.doc(notif.id).set(notif.toMap());
    // Push notification is sent automatically via Cloud Function trigger
    // (functions/src/sendPushNotification.ts) when this document is created.
  }

  Future<void> markNotificationRead(String id) async {
    await _notifications.doc(id).update({'read': true});
  }

  Future<void> markAllNotificationsRead(String uid) async {
    final snap = await _notifications
        .where('toUid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Stream<List<NotificationModel>> getNotifications(String uid) {
    return _notifications
        .where('toUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => NotificationModel.fromMap(d.data()))
              .toList(),
        );
  }

  Stream<int> getUnreadNotificationCount(String uid) {
    return _notifications
        .where('toUid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ═══════════════════════════════════════
  // CHATS & MESSAGES
  // ═══════════════════════════════════════
  Future<ChatModel?> getChat(String chatId) async {
    final doc = await _chats.doc(chatId).get();
    if (!doc.exists) return null;
    return ChatModel.fromMap(doc.data()!);
  }

  Future<ChatModel> getOrCreateChat(String uid1, String uid2) async {
    final participants = [uid1, uid2]..sort();
    final chatId = '${participants[0]}_${participants[1]}';
    final doc = await _chats.doc(chatId).get();
    if (doc.exists) {
      return ChatModel.fromMap(doc.data()!);
    }
    final chat = ChatModel(chatId: chatId, participants: participants);
    await _chats.doc(chatId).set(chat.toMap());
    return chat;
  }

  Future<void> sendMessage(MessageModel message) async {
    final batch = _db.batch();
    batch.set(
      _chats.doc(message.chatId).collection('messages').doc(message.id),
      message.toMap(),
    );
    batch.update(_chats.doc(message.chatId), {
      'lastMessage': message.text.isNotEmpty ? message.text : '📷 Media',
      'lastSenderUid': message.senderUid,
      'lastMessageAt': Timestamp.fromDate(DateTime.now()),
    });
    await batch.commit();
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => MessageModel.fromMap(d.data())).toList(),
        );
  }

  Stream<List<ChatModel>> getUserChats(String uid) {
    return _chats
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => ChatModel.fromMap(d.data())).toList(),
        );
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    await _chats.doc(chatId).collection('messages').doc(messageId).delete();
  }

  Future<void> updateMessage(
    String chatId,
    String messageId,
    String newText,
  ) async {
    await _chats.doc(chatId).collection('messages').doc(messageId).update({
      'text': newText,
      'isEdited': true,
    });
    // Update the chat's lastMessage if this was the latest message
    final lastMsg = await _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (lastMsg.docs.isNotEmpty && lastMsg.docs.first.id == messageId) {
      await _chats.doc(chatId).update({'lastMessage': newText});
    }
  }

  // ═══════════════════════════════════════
  // GROUP CHATS
  // ═══════════════════════════════════════
  Future<void> createGroupChat(GroupChatModel group) async {
    await _groupChats.doc(group.id).set(group.toMap());
  }

  Future<GroupChatModel?> getGroupChat(String groupId) async {
    final doc = await _groupChats.doc(groupId).get();
    if (!doc.exists) return null;
    return GroupChatModel.fromMap(doc.data()!);
  }

  Stream<GroupChatModel?> groupChatStream(String groupId) {
    return _groupChats.doc(groupId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return GroupChatModel.fromMap(snap.data()!);
    });
  }

  Stream<List<GroupChatModel>> getUserGroupChats(String uid) {
    return _groupChats
        .where('members', arrayContains: uid)
        .where('status', isEqualTo: 'active')
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => GroupChatModel.fromMap(d.data())).toList());
  }

  Future<void> updateGroupChat(
      String groupId, Map<String, dynamic> data) async {
    await _groupChats.doc(groupId).update(data);
  }

  Future<void> sendGroupMessage(GroupMessageModel message) async {
    final batch = _db.batch();
    batch.set(
      _groupChats
          .doc(message.groupId)
          .collection('messages')
          .doc(message.id),
      message.toMap(),
    );
    batch.update(_groupChats.doc(message.groupId), {
      'lastMessage': message.text.isNotEmpty ? message.text : '📷 Media',
      'lastSenderUid': message.senderUid,
      'lastMessageAt': Timestamp.fromDate(DateTime.now()),
      'lastActivityAt': Timestamp.fromDate(DateTime.now()),
      'messageCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Stream<List<GroupMessageModel>> getGroupMessages(String groupId) {
    return _groupChats
        .doc(groupId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => GroupMessageModel.fromMap(d.data())).toList());
  }

  Future<void> deleteGroupMessage(String groupId, String messageId) async {
    await _groupChats
        .doc(groupId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  Future<void> updateGroupMessage(
      String groupId, String messageId, String newText) async {
    await _groupChats
        .doc(groupId)
        .collection('messages')
        .doc(messageId)
        .update({
      'text': newText,
      'isEdited': true,
    });
    final lastMsg = await _groupChats
        .doc(groupId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (lastMsg.docs.isNotEmpty && lastMsg.docs.first.id == messageId) {
      await _groupChats.doc(groupId).update({'lastMessage': newText});
    }
  }

  Future<void> addGroupMember(String groupId, String uid) async {
    await _groupChats.doc(groupId).update({
      'members': FieldValue.arrayUnion([uid]),
      'memberCount': FieldValue.increment(1),
    });
  }

  Future<void> removeGroupMember(String groupId, String uid) async {
    await _groupChats.doc(groupId).update({
      'members': FieldValue.arrayRemove([uid]),
      'admins': FieldValue.arrayRemove([uid]),
      'memberCount': FieldValue.increment(-1),
    });
  }

  Future<void> addGroupAdmin(String groupId, String uid) async {
    await _groupChats.doc(groupId).update({
      'admins': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> removeGroupAdmin(String groupId, String uid) async {
    await _groupChats.doc(groupId).update({
      'admins': FieldValue.arrayRemove([uid]),
    });
  }

  // ═══════════════════════════════════════
  // GROUP INVITATIONS
  // ═══════════════════════════════════════
  Future<void> createGroupInvitation(GroupInviteModel invite) async {
    await _groupInvitations.doc(invite.id).set(invite.toMap());
  }

  Future<GroupInviteModel?> getGroupInvitation(String inviteId) async {
    final doc = await _groupInvitations.doc(inviteId).get();
    if (!doc.exists) return null;
    return GroupInviteModel.fromMap(doc.data()!);
  }

  Stream<List<GroupInviteModel>> getPendingGroupInvitations(String uid) {
    return _groupInvitations
        .where('inviteeUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => GroupInviteModel.fromMap(d.data())).toList());
  }

  Future<void> updateGroupInvitationStatus(
      String inviteId, String status) async {
    await _groupInvitations.doc(inviteId).update({'status': status});
  }

  Future<bool> hasPendingGroupInvite(
      String groupId, String inviteeUid) async {
    final snap = await _groupInvitations
        .where('groupId', isEqualTo: groupId)
        .where('inviteeUid', isEqualTo: inviteeUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // ═══════════════════════════════════════
  // REWARDS
  // ═══════════════════════════════════════
  Future<List<RewardModel>> getActiveRewards() async {
    final snap = await _rewards
        .where('isActive', isEqualTo: true)
        .orderBy('pointsCost', descending: false)
        .get();
    return snap.docs.map((d) => RewardModel.fromMap(d.data())).toList();
  }

  Future<RewardModel?> getReward(String id) async {
    final doc = await _rewards.doc(id).get();
    if (!doc.exists) return null;
    return RewardModel.fromMap(doc.data()!);
  }

  Future<void> createRedemption(RedemptionModel redemption) async {
    await _redemptions.doc(redemption.id).set(redemption.toMap());
  }

  Future<List<RedemptionModel>> getUserRedemptions(String uid) async {
    final snap = await _redemptions
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => RedemptionModel.fromMap(d.data())).toList();
  }

  // Admin CRUD for rewards
  Future<List<RewardModel>> getAllRewards() async {
    final snap = await _rewards.orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => RewardModel.fromMap(d.data())).toList();
  }

  Future<void> createReward(RewardModel reward) async {
    await _rewards.doc(reward.id).set(reward.toMap());
  }

  Future<void> updateReward(String id, Map<String, dynamic> data) async {
    await _rewards.doc(id).update(data);
  }

  Future<void> deleteReward(String id) async {
    await _rewards.doc(id).delete();
  }

  // ═══════════════════════════════════════
  // REPORTS
  // ═══════════════════════════════════════
  Future<void> createReport(ReportModel report) async {
    await _reports.doc(report.id).set(report.toMap());
  }

  Future<List<ReportModel>> getPendingReports() async {
    final snap = await _reports
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => ReportModel.fromMap(d.data())).toList();
  }

  // ═══════════════════════════════════════
  // BLOCKS
  // ═══════════════════════════════════════
  Future<void> blockUser(String blockerUid, String blockedUid) async {
    final block = BlockModel(blockerUid: blockerUid, blockedUid: blockedUid);
    await _blocks.doc('${blockerUid}_$blockedUid').set(block.toMap());
  }

  Future<void> unblockUser(String blockerUid, String blockedUid) async {
    await _blocks.doc('${blockerUid}_$blockedUid').delete();
  }

  Future<bool> isBlocked(String blockerUid, String blockedUid) async {
    final doc = await _blocks.doc('${blockerUid}_$blockedUid').get();
    return doc.exists;
  }

  Future<bool> isBlockedByEither(String uid1, String uid2) async {
    final a = await isBlocked(uid1, uid2);
    if (a) return true;
    return await isBlocked(uid2, uid1);
  }

  Future<List<String>> getBlockedUids(String uid) async {
    final snap = await _blocks.where('blockerUid', isEqualTo: uid).get();
    return snap.docs.map((d) => d.data()['blockedUid'] as String).toList();
  }

  // ═══════════════════════════════════════
  // COUNTERS (atomic)
  // ═══════════════════════════════════════
  Future<void> incrementFollowers(String uid) async {
    await _users.doc(uid).update({'followersCount': FieldValue.increment(1)});
  }

  Future<void> decrementFollowers(String uid) async {
    await _users.doc(uid).update({'followersCount': FieldValue.increment(-1)});
  }

  Future<void> incrementFollowing(String uid) async {
    await _users.doc(uid).update({'followingCount': FieldValue.increment(1)});
  }

  Future<void> decrementFollowing(String uid) async {
    await _users.doc(uid).update({'followingCount': FieldValue.increment(-1)});
  }

  Future<void> incrementViews(String reelId) async {
    final reel = await getReel(reelId);
    if (reel == null) return;
    final batch = _db.batch();
    batch.update(_reels.doc(reelId), {'viewsCount': FieldValue.increment(1)});
    // Auto-disable limited reels when view cap is reached
    if (reel.isLimited &&
        reel.maxViews > 0 &&
        reel.viewsCount + 1 >= reel.maxViews) {
      batch.update(_reels.doc(reelId), {'isActive': false});
    }
    await batch.commit();
  }

  Future<void> incrementTotalLikes(String uid) async {
    await _users.doc(uid).update({'totalLikes': FieldValue.increment(1)});
  }

  Future<void> decrementTotalLikes(String uid) async {
    await _users.doc(uid).update({'totalLikes': FieldValue.increment(-1)});
  }

  Future<void> updatePointsBalance(String uid, int points) async {
    await _users.doc(uid).update({
      'pointsBalance': FieldValue.increment(points),
    });
  }

  // ═══════════════════════════════════════
  // SEED DATA (for rewards)
  // ═══════════════════════════════════════
  Future<void> seedRewardsIfEmpty() async {
    final snap = await _rewards.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final rewards = [
      RewardModel(
        id: 'reward_nike_50',
        title: 'Nike ₹500 Voucher',
        description:
            'Get a ₹500 discount on Nike products. Valid for 30 days after redemption.',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a6/Logo_NIKE.svg/200px-Logo_NIKE.svg.png',
        pointsCost: 500,
        stock: 100,
      ),
      RewardModel(
        id: 'reward_amazon_25',
        title: 'Amazon ₹250 Gift Card',
        description:
            'Amazon gift card worth ₹250. Can be applied to your Amazon account.',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a9/Amazon_logo.svg/200px-Amazon_logo.svg.png',
        pointsCost: 250,
        stock: 200,
      ),
      RewardModel(
        id: 'reward_spotify_1m',
        title: 'Spotify Premium 1 Month',
        description:
            'One month of Spotify Premium subscription. Enjoy ad-free music streaming.',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/8/84/Spotify_icon.svg/200px-Spotify_icon.svg.png',
        pointsCost: 300,
        stock: 50,
      ),
      RewardModel(
        id: 'reward_starbucks',
        title: 'Starbucks ₹200 Card',
        description: 'Enjoy a coffee on us! Starbucks gift card worth ₹200.',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/en/thumb/d/d3/Starbucks_Corporation_Logo_2011.svg/200px-Starbucks_Corporation_Logo_2011.svg.png',
        pointsCost: 200,
        stock: 150,
      ),
      RewardModel(
        id: 'reward_custom_badge',
        title: 'Creator Badge',
        description:
            'Unlock an exclusive Creator badge on your profile! Show off your content creation skills.',
        imageUrl: '',
        pointsCost: 100,
        stock: -1, // unlimited
      ),
      RewardModel(
        id: 'reward_profile_theme',
        title: 'Premium Profile Theme',
        description:
            'Unlock exclusive profile color themes to make your profile stand out.',
        imageUrl: '',
        pointsCost: 150,
        stock: -1,
      ),
    ];

    final batch = _db.batch();
    for (final reward in rewards) {
      batch.set(_rewards.doc(reward.id), reward.toMap());
    }
    await batch.commit();
  }

  // ═══════════════════════════════════════
  // POSTS
  // ═══════════════════════════════════════
  Future<void> createPost(PostModel post) async {
    await _posts.doc(post.postId).set(post.toMap());
  }

  Future<PostModel?> getPost(String postId) async {
    final doc = await _posts.doc(postId).get();
    if (!doc.exists) return null;
    return PostModel.fromMap(doc.data()!);
  }

  Future<List<PostModel>> getPostsByUser(String uid) async {
    final snap = await _posts
        .where('creatorUid', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => PostModel.fromMap(d.data())).toList();
  }

  Future<List<PostModel>> getPublicPosts({int limit = 20}) async {
    final snap = await _posts
        .where('visibility', isEqualTo: 'public')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => PostModel.fromMap(d.data())).toList();
  }

  Future<List<PostModel>> getFeedPosts(
    List<String> followingUids, {
    int limit = 20,
  }) async {
    if (followingUids.isEmpty) return [];
    final chunks = <List<String>>[];
    for (var i = 0; i < followingUids.length; i += 30) {
      chunks.add(
        followingUids.sublist(
          i,
          i + 30 > followingUids.length ? followingUids.length : i + 30,
        ),
      );
    }
    final allPosts = <PostModel>[];
    for (final chunk in chunks) {
      final snap = await _posts
          .where('creatorUid', whereIn: chunk)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      allPosts.addAll(snap.docs.map((d) => PostModel.fromMap(d.data())));
    }
    allPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return allPosts.take(limit).toList();
  }

  Future<void> deletePost(String postId) async {
    await _posts.doc(postId).update({'isActive': false});
  }

  Future<void> likePost(String uid, String postId, {String? creatorUid}) async {
    final batch = _db.batch();
    batch.set(_likes.doc('${uid}_post_$postId'), {
      'uid': uid,
      'postId': postId,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
    batch.update(_posts.doc(postId), {'likesCount': FieldValue.increment(1)});
    await batch.commit();

    // Create notification for post creator
    if (creatorUid != null && creatorUid != uid) {
      await addNotification(
        NotificationModel(
          id: '${uid}_like_post_$postId',
          toUid: creatorUid,
          fromUid: uid,
          type: 'like',
          message: 'liked your post',
          postId: postId,
        ),
      );
    }
  }

  Future<void> unlikePost(String uid, String postId) async {
    final batch = _db.batch();
    batch.delete(_likes.doc('${uid}_post_$postId'));
    batch.update(_posts.doc(postId), {'likesCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  Future<bool> hasLikedPost(String uid, String postId) async {
    final doc = await _likes.doc('${uid}_post_$postId').get();
    return doc.exists;
  }

  // ═══════════════════════════════════════
  // STORIES
  // ═══════════════════════════════════════
  Future<void> createStory(StoryModel story) async {
    await _stories.doc(story.storyId).set(story.toMap());
  }

  Future<List<StoryModel>> getActiveStories(String uid) async {
    final now = DateTime.now();
    final snap = await _stories
        .where('creatorUid', isEqualTo: uid)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('expiresAt', descending: true)
        .get();
    return snap.docs.map((d) => StoryModel.fromMap(d.data())).toList();
  }

  Future<List<StoryModel>> getFollowingStories(
    List<String> followingUids, {
    String? currentUid,
  }) async {
    if (followingUids.isEmpty) return [];
    final now = DateTime.now();
    final allStories = <StoryModel>[];
    // chunk to avoid Firestore 30-item limit on whereIn
    for (var i = 0; i < followingUids.length; i += 30) {
      final chunk = followingUids.sublist(
        i,
        i + 30 > followingUids.length ? followingUids.length : i + 30,
      );
      final snap = await _stories
          .where('creatorUid', whereIn: chunk)
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
          .get();
      allStories.addAll(snap.docs.map((d) => StoryModel.fromMap(d.data())));
    }
    // Filter out close_friends stories if current user is not in creator's close friends
    if (currentUid != null) {
      final closeFriendsCache = <String, List<String>>{};
      final filtered = <StoryModel>[];
      for (final story in allStories) {
        if (story.audience == 'close_friends') {
          if (!closeFriendsCache.containsKey(story.creatorUid)) {
            closeFriendsCache[story.creatorUid] = await getCloseFriends(
              story.creatorUid,
            );
          }
          if (closeFriendsCache[story.creatorUid]!.contains(currentUid)) {
            filtered.add(story);
          }
        } else {
          filtered.add(story);
        }
      }
      return filtered;
    }
    return allStories;
  }

  Future<void> markStoryViewed(String storyId, String viewerUid) async {
    await _stories.doc(storyId).update({
      'viewerUids': FieldValue.arrayUnion([viewerUid]),
      'viewCount': FieldValue.increment(1),
    });
  }

  Future<void> deleteStory(String storyId) async {
    await _stories.doc(storyId).delete();
  }

  Future<void> likeStory(String storyId, String uid) async {
    await _stories.doc(storyId).update({
      'likedByUids': FieldValue.arrayUnion([uid]),
      'likesCount': FieldValue.increment(1),
    });
  }

  Future<void> unlikeStory(String storyId, String uid) async {
    await _stories.doc(storyId).update({
      'likedByUids': FieldValue.arrayRemove([uid]),
      'likesCount': FieldValue.increment(-1),
    });
  }

  Future<void> addStoryComment(String storyId, CommentModel comment) async {
    await _stories
        .doc(storyId)
        .collection('comments')
        .doc(comment.id)
        .set(comment.toMap());
  }

  Stream<List<CommentModel>> getStoryComments(String storyId) {
    return _stories
        .doc(storyId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => CommentModel.fromMap(d.data())).toList(),
        );
  }

  // ═══════════════════════════════════════
  // STORY REACTIONS
  // ═══════════════════════════════════════
  Future<void> addStoryReaction(String storyId, String userId, String reactionType) async {
    final docId = '${userId}_$storyId';
    final reaction = StoryReactionModel(
      id: docId,
      storyId: storyId,
      userId: userId,
      reactionType: reactionType,
    );
    await _storyReactions.doc(docId).set(reaction.toMap());
  }

  Future<void> removeStoryReaction(String storyId, String userId) async {
    final docId = '${userId}_$storyId';
    await _storyReactions.doc(docId).delete();
  }

  Future<String?> getUserStoryReaction(String storyId, String userId) async {
    final docId = '${userId}_$storyId';
    final doc = await _storyReactions.doc(docId).get();
    if (!doc.exists) return null;
    return doc.data()?['reactionType'] as String?;
  }

  Stream<Map<String, int>> getStoryReactionCounts(String storyId) {
    return _storyReactions
        .where('storyId', isEqualTo: storyId)
        .snapshots()
        .map((snap) {
      final counts = <String, int>{};
      for (final doc in snap.docs) {
        final emoji = doc.data()['reactionType'] as String? ?? '';
        if (emoji.isNotEmpty) {
          counts[emoji] = (counts[emoji] ?? 0) + 1;
        }
      }
      return counts;
    });
  }

  // ═══════════════════════════════════════
  // POINT TRANSFERS
  // ═══════════════════════════════════════
  Future<void> logPointTransfer(PointTransferModel transfer) async {
    await _pointTransfers.doc(transfer.id).set(transfer.toMap());
  }

  // ═══════════════════════════════════════
  // VAULT REELS
  // ═══════════════════════════════════════
  Future<void> addToVault(String uid, String reelId) async {
    await _vaultReels.doc('${uid}_$reelId').set({
      'uid': uid,
      'reelId': reelId,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> removeFromVault(String uid, String reelId) async {
    await _vaultReels.doc('${uid}_$reelId').delete();
  }

  Future<bool> isInVault(String uid, String reelId) async {
    final doc = await _vaultReels.doc('${uid}_$reelId').get();
    return doc.exists;
  }

  Future<List<String>> getVaultReelIds(String uid) async {
    final snap = await _vaultReels
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .where((d) => d.data()['reelId'] != null)
        .map((d) => d.data()['reelId'] as String)
        .toList();
  }

  // ═══════════════════════════════════════
  // CLOSE FRIENDS
  // ═══════════════════════════════════════
  Future<List<String>> getCloseFriends(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return [];
    final data = doc.data();
    return List<String>.from(data?['closeFriends'] ?? []);
  }

  Future<void> updateCloseFriends(String uid, List<String> friends) async {
    await _users.doc(uid).update({'closeFriends': friends});
  }

  // ═══════════════════════════════════════
  // POST SAVE (BOOKMARKS)
  // ═══════════════════════════════════════
  Future<void> savePost(String uid, String postId) async {
    await _db.collection('savedPosts').doc('${uid}_$postId').set({
      'uid': uid,
      'postId': postId,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unsavePost(String uid, String postId) async {
    await _db.collection('savedPosts').doc('${uid}_$postId').delete();
  }

  Future<bool> hasSavedPost(String uid, String postId) async {
    final doc = await _db.collection('savedPosts').doc('${uid}_$postId').get();
    return doc.exists;
  }

  Future<List<String>> getSavedPostIds(String uid) async {
    final snap = await _db
        .collection('savedPosts')
        .where('uid', isEqualTo: uid)
        .orderBy('savedAt', descending: true)
        .get();
    return snap.docs.map((d) => d.data()['postId'] as String).toList();
  }

  // ═══════════════════════════════════════
  // REEL RATINGS
  // ═══════════════════════════════════════
  Future<void> rateReel(String uid, String reelId, int rating) async {
    final docId = '${uid}_$reelId';
    final existing = await _db.collection('reelRatings').doc(docId).get();
    final batch = _db.batch();

    if (existing.exists) {
      // Update existing rating
      final oldRating = existing.data()?['rating'] ?? 0;
      batch.update(_db.collection('reelRatings').doc(docId), {
        'rating': rating,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      batch.update(_reels.doc(reelId), {
        'ratingSum': FieldValue.increment(rating - oldRating),
      });
    } else {
      // New rating
      batch.set(_db.collection('reelRatings').doc(docId), {
        'uid': uid,
        'reelId': reelId,
        'rating': rating,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      batch.update(_reels.doc(reelId), {
        'ratingSum': FieldValue.increment(rating),
        'totalRatings': FieldValue.increment(1),
      });
    }
    await batch.commit();

    // Update average rating
    final reel = await getReel(reelId);
    if (reel != null && reel.totalRatings > 0) {
      final avg =
          (reel.ratingSum +
              (existing.exists
                  ? rating - (existing.data()?['rating'] ?? 0)
                  : rating)) /
          (reel.totalRatings + (existing.exists ? 0 : 1));
      await _reels.doc(reelId).update({'averageRating': avg});
    }
  }

  Future<int?> getUserReelRating(String uid, String reelId) async {
    final doc = await _db.collection('reelRatings').doc('${uid}_$reelId').get();
    if (!doc.exists) return null;
    return doc.data()?['rating'] as int?;
  }

  // ═══════════════════════════════════════
  // LEADERBOARDS
  // ═══════════════════════════════════════
  Future<List<Map<String, dynamic>>> getWeeklyLeaderboard({
    int limit = 50,
  }) async {
    final snap = await _db
        .collection('leaderboardWeekly')
        .orderBy('completedWatches', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<List<Map<String, dynamic>>> getMonthlyLeaderboard({
    int limit = 50,
  }) async {
    final snap = await _db
        .collection('leaderboardMonthly')
        .orderBy('completedWatches', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<int?> getUserRank(String uid, String collection) async {
    final snap = await _db
        .collection(collection)
        .orderBy('completedWatches', descending: true)
        .get();
    for (int i = 0; i < snap.docs.length; i++) {
      if (snap.docs[i].data()['uid'] == uid) return i + 1;
    }
    return null;
  }

  // ═══════════════════════════════════════
  // ADDITIONAL HELPERS
  // ═══════════════════════════════════════
  Future<void> deleteNotification(String id) async {
    await _notifications.doc(id).delete();
  }

  Future<void> deleteNotificationByTypeAndUsers(String toUid, String fromUid, String type) async {
    final snap = await _notifications
        .where('toUid', isEqualTo: toUid)
        .where('fromUid', isEqualTo: fromUid)
        .where('type', isEqualTo: type)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> recalculateFollowCounts(String uid) async {
    final followersSnap = await _follows
        .where('followingId', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .get();
    final followingSnap = await _follows
        .where('followerId', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .get();
    final actualFollowers = followersSnap.docs.length;
    final actualFollowing = followingSnap.docs.length;
    await _users.doc(uid).update({
      'followersCount': actualFollowers,
      'followingCount': actualFollowing,
    });
  }

  Future<void> updatePost(String postId, Map<String, dynamic> data) async {
    await _posts.doc(postId).update(data);
  }

  Future<List<UserModel>> getPostLikers(String postId) async {
    final snap = await _likes.where('postId', isEqualTo: postId).get();
    final users = <UserModel>[];
    for (final doc in snap.docs) {
      final uid = doc.data()['uid'] as String?;
      if (uid == null || uid.isEmpty) continue;
      final user = await getUser(uid);
      if (user != null) users.add(user);
    }
    return users;
  }

  Future<String> getFollowStatus(String followerId, String followingId) async {
    final doc = await _follows.doc('${followerId}_$followingId').get();
    if (!doc.exists) return 'none';
    return doc.data()?['status'] ?? 'none';
  }

  Stream<int> getUnreadChatCount(String uid) {
    return _chats.where('participants', arrayContains: uid).snapshots().map((
      snap,
    ) {
      int count = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final lastSender = data['lastMessageSenderUid'] ?? '';
        final lastMessage = data['lastMessage'] ?? '';
        if (lastSender.isNotEmpty &&
            lastSender != uid &&
            lastMessage.isNotEmpty) {
          count++;
        }
      }
      return count;
    });
  }
}

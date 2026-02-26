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

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Collection References ──
  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _reels => _db.collection('reels');
  CollectionReference<Map<String, dynamic>> get _follows => _db.collection('follows');
  CollectionReference<Map<String, dynamic>> get _transactions => _db.collection('transactions');
  CollectionReference<Map<String, dynamic>> get _notifications => _db.collection('notifications');
  CollectionReference<Map<String, dynamic>> get _comments => _db.collection('comments');
  CollectionReference<Map<String, dynamic>> get _chats => _db.collection('chats');
  CollectionReference<Map<String, dynamic>> get _rewards => _db.collection('rewards');
  CollectionReference<Map<String, dynamic>> get _redemptions => _db.collection('redemptions');
  CollectionReference<Map<String, dynamic>> get _reports => _db.collection('reports');
  CollectionReference<Map<String, dynamic>> get _blocks => _db.collection('blocks');
  CollectionReference<Map<String, dynamic>> get _likes => _db.collection('likes');
  CollectionReference<Map<String, dynamic>> get _saves => _db.collection('saves');
  CollectionReference<Map<String, dynamic>> get _posts => _db.collection('posts');
  CollectionReference<Map<String, dynamic>> get _stories => _db.collection('stories');

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

  Future<List<ReelModel>> getFeedReels(List<String> followingUids, {int limit = 20}) async {
    if (followingUids.isEmpty) return [];
    // Firestore whereIn limit is 30
    final chunks = <List<String>>[];
    for (var i = 0; i < followingUids.length; i += 30) {
      chunks.add(followingUids.sublist(i, i + 30 > followingUids.length ? followingUids.length : i + 30));
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

  Future<List<ReelModel>> getReelsByHashtag(String hashtag, {int limit = 20}) async {
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

  Future<void> updateFollowStatus(String followerId, String followingId, String status) async {
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

  Future<List<String>> getFollowingUids(String uid) async {
    final follows = await getFollowing(uid);
    return follows.map((f) => f.followingId).toList();
  }

  // ═══════════════════════════════════════
  // LIKES
  // ═══════════════════════════════════════
  Future<void> likeReel(String uid, String reelId) async {
    final batch = _db.batch();
    batch.set(_likes.doc('${uid}_$reelId'), {
      'uid': uid,
      'reelId': reelId,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
    batch.update(_reels.doc(reelId), {'likesCount': FieldValue.increment(1)});
    await batch.commit();
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

  // ═══════════════════════════════════════
  // COMMENTS
  // ═══════════════════════════════════════
  Future<void> addComment(CommentModel comment) async {
    final batch = _db.batch();
    batch.set(_comments.doc(comment.id), comment.toMap());
    batch.update(_reels.doc(comment.reelId), {'commentsCount': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> addPostComment(CommentModel comment) async {
    final batch = _db.batch();
    batch.set(_comments.doc(comment.id), comment.toMap());
    batch.update(_posts.doc(comment.reelId), {'commentsCount': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> deleteComment(String commentId, String reelId) async {
    final batch = _db.batch();
    batch.delete(_comments.doc(commentId));
    batch.update(_reels.doc(reelId), {'commentsCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  Future<void> deletePostComment(String commentId, String postId) async {
    final batch = _db.batch();
    batch.delete(_comments.doc(commentId));
    batch.update(_posts.doc(postId), {'commentsCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  Stream<List<CommentModel>> getComments(String reelId) {
    return _comments
        .where('reelId', isEqualTo: reelId)
        .where('parentId', isEqualTo: '')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CommentModel.fromMap(d.data())).toList());
  }

  Stream<List<CommentModel>> getReplies(String parentId) {
    return _comments
        .where('parentId', isEqualTo: parentId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CommentModel.fromMap(d.data())).toList());
  }

  // ═══════════════════════════════════════
  // TRANSACTIONS
  // ═══════════════════════════════════════
  Future<void> addTransaction(TransactionModel txn) async {
    await _transactions.doc(txn.id).set(txn.toMap());
  }

  Future<List<TransactionModel>> getUserTransactions(String uid, {int limit = 50}) async {
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
        .map((snap) => snap.docs.map((d) => NotificationModel.fromMap(d.data())).toList());
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
        .map((snap) => snap.docs.map((d) => MessageModel.fromMap(d.data())).toList());
  }

  Stream<List<ChatModel>> getUserChats(String uid) {
    return _chats
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ChatModel.fromMap(d.data())).toList());
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
    await _reels.doc(reelId).update({'viewsCount': FieldValue.increment(1)});
  }

  Future<void> incrementTotalLikes(String uid) async {
    await _users.doc(uid).update({'totalLikes': FieldValue.increment(1)});
  }

  Future<void> decrementTotalLikes(String uid) async {
    await _users.doc(uid).update({'totalLikes': FieldValue.increment(-1)});
  }

  Future<void> updatePointsBalance(String uid, int points) async {
    await _users.doc(uid).update({'pointsBalance': FieldValue.increment(points)});
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
        description: 'Get a ₹500 discount on Nike products. Valid for 30 days after redemption.',
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a6/Logo_NIKE.svg/200px-Logo_NIKE.svg.png',
        pointsCost: 500,
        stock: 100,
      ),
      RewardModel(
        id: 'reward_amazon_25',
        title: 'Amazon ₹250 Gift Card',
        description: 'Amazon gift card worth ₹250. Can be applied to your Amazon account.',
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a9/Amazon_logo.svg/200px-Amazon_logo.svg.png',
        pointsCost: 250,
        stock: 200,
      ),
      RewardModel(
        id: 'reward_spotify_1m',
        title: 'Spotify Premium 1 Month',
        description: 'One month of Spotify Premium subscription. Enjoy ad-free music streaming.',
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/84/Spotify_icon.svg/200px-Spotify_icon.svg.png',
        pointsCost: 300,
        stock: 50,
      ),
      RewardModel(
        id: 'reward_starbucks',
        title: 'Starbucks ₹200 Card',
        description: 'Enjoy a coffee on us! Starbucks gift card worth ₹200.',
        imageUrl: 'https://upload.wikimedia.org/wikipedia/en/thumb/d/d3/Starbucks_Corporation_Logo_2011.svg/200px-Starbucks_Corporation_Logo_2011.svg.png',
        pointsCost: 200,
        stock: 150,
      ),
      RewardModel(
        id: 'reward_custom_badge',
        title: 'Creator Badge',
        description: 'Unlock an exclusive Creator badge on your profile! Show off your content creation skills.',
        imageUrl: '',
        pointsCost: 100,
        stock: -1, // unlimited
      ),
      RewardModel(
        id: 'reward_profile_theme',
        title: 'Premium Profile Theme',
        description: 'Unlock exclusive profile color themes to make your profile stand out.',
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

  Future<List<PostModel>> getFeedPosts(List<String> followingUids, {int limit = 20}) async {
    if (followingUids.isEmpty) return [];
    final chunks = <List<String>>[];
    for (var i = 0; i < followingUids.length; i += 30) {
      chunks.add(followingUids.sublist(i, i + 30 > followingUids.length ? followingUids.length : i + 30));
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

  Future<void> likePost(String uid, String postId) async {
    final batch = _db.batch();
    batch.set(_likes.doc('${uid}_post_$postId'), {
      'uid': uid,
      'postId': postId,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
    batch.update(_posts.doc(postId), {'likesCount': FieldValue.increment(1)});
    await batch.commit();
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

  Future<List<StoryModel>> getFollowingStories(List<String> followingUids) async {
    if (followingUids.isEmpty) return [];
    final now = DateTime.now();
    final allStories = <StoryModel>[];
    // chunk to avoid Firestore 30-item limit on whereIn
    for (var i = 0; i < followingUids.length; i += 30) {
      final chunk = followingUids.sublist(i, i + 30 > followingUids.length ? followingUids.length : i + 30);
      final snap = await _stories
          .where('creatorUid', whereIn: chunk)
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
          .get();
      allStories.addAll(snap.docs.map((d) => StoryModel.fromMap(d.data())));
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
}

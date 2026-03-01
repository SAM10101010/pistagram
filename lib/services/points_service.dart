import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/point_transfer_model.dart';
import '../models/notification_model.dart';
import 'firestore_service.dart';
import 'fraud_service.dart';
import 'level_service.dart';
import 'streak_service.dart';
import 'reaction_reward_service.dart';
import 'achievement_service.dart';
import 'campaign_service.dart';
import 'series_service.dart';

/// Converts raw exception messages to user-friendly text.
String _friendlyError(Object e) {
  final msg = e.toString();
  if (msg.contains('PERMISSION_DENIED') || msg.contains('permission-denied')) {
    return 'You don\'t have permission to perform this action. Please try again later.';
  }
  if (msg.contains('UNAVAILABLE') || msg.contains('unavailable')) {
    return 'Service is temporarily unavailable. Please check your internet connection.';
  }
  if (msg.contains('NOT_FOUND') || msg.contains('not-found')) {
    return 'The requested data was not found.';
  }
  if (msg.contains('DEADLINE_EXCEEDED') || msg.contains('deadline-exceeded')) {
    return 'Request timed out. Please try again.';
  }
  // Strip 'Exception: ' prefix
  return msg.replaceFirst('Exception: ', '');
}

class PointsService {
  static const String _pointsKey = 'total_points';
  static const String _completedReelsKeyPrefix = 'completed_reels_';
  @Deprecated('Use _completedReelsKeyPrefix + uid instead')
  static const String _completedReelsKeyLegacy = 'completed_reels';
  static const int dailyEarningCap = 100;
  static final _random = Random();
  final _uuid = const Uuid();

  final FirestoreService _firestoreService = FirestoreService();
  final FraudService _fraudService = FraudService();
  final LevelService _levelService = LevelService();
  final StreakService _streakService = StreakService();
  final ReactionRewardService _reactionService = ReactionRewardService();
  final AchievementService _achievementService = AchievementService();
  final CampaignService _campaignService = CampaignService();
  final SeriesService _seriesService = SeriesService();

  /// Weighted random points: 1-5 (~75%), 6-10 (~25%)
  static int generateRandomPoints() {
    final roll = _random.nextDouble();
    if (roll < 0.75) {
      return _random.nextInt(5) + 1;
    } else {
      return _random.nextInt(5) + 6;
    }
  }

  Future<int> getPoints({String? uid}) async {
    // Always read from Firestore as the single source of truth
    if (uid != null) {
      final user = await _firestoreService.getUser(uid);
      if (user != null) {
        // Sync SharedPreferences cache with Firestore value
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_pointsKey, user.pointsBalance);
        return user.pointsBalance;
      }
    }
    // Fallback to local cache only if uid not available
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pointsKey) ?? 0;
  }

  /// Add points — locked for 24h before becoming spendable.
  /// Also triggers streak, level, achievement, campaign, and series tracking.
  Future<Map<String, dynamic>> addPoints(
    int amount, {
    String? uid,
    String? reelId,
  }) async {
    final result = <String, dynamic>{'points': amount};

    // Check if user is suspended
    if (uid != null) {
      final user = await _firestoreService.getUser(uid);
      if (user == null || user.accountStatus != 'active') {
        throw Exception('Account is not active — cannot earn points');
      }
    }

    // Check if reel is private
    if (reelId != null) {
      final reel = await _firestoreService.getReel(reelId);
      if (reel != null && reel.visibility == 'private') {
        throw Exception('Cannot earn points from private reels');
      }
    }

    // Check daily cap
    if (uid != null && await _fraudService.hasReachedDailyCap(uid)) {
      throw Exception('Daily earning limit reached');
    }

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_pointsKey) ?? 0;
    final newTotal = current + amount;
    await prefs.setInt(_pointsKey, newTotal);

    if (uid != null) {
      // Log transaction
      final txn = TransactionModel(
        id: _uuid.v4(),
        uid: uid,
        type: 'earned',
        amount: amount,
        reason: 'Watched reel to completion',
        reelId: reelId ?? '',
      );
      await _firestoreService.addTransaction(txn);

      // Points go to both lockedPoints AND pointsBalance immediately
      // Also track totalPointsEarned and totalWatchedReels for analytics
      await _firestoreService.updateUser(uid, {
        'lockedPoints': FieldValue.increment(amount),
        'pointsBalance': FieldValue.increment(amount),
        'totalPointsEarned': FieldValue.increment(amount),
        'totalWatchedReels': FieldValue.increment(1),
      });

      // Track engagement for reaction bonuses
      if (reelId != null) {
        await _reactionService.onReelWatched(uid, reelId, amount);
      }

      // Update level
      final newLevel = await _levelService.addEarnedPoints(uid, amount);
      if (newLevel != null) {
        result['levelUp'] = newLevel;
        await _achievementService.checkAndAward(
          uid,
          'levelup',
          context: {'level': newLevel},
        );
      }

      // Update streak
      final streakInfo = await _streakService.onReelCompleted(uid);
      if (streakInfo != null) {
        result['streak'] = streakInfo;
        if (streakInfo['isMilestone'] == true) {
          await _achievementService.checkAndAward(
            uid,
            'streak',
            context: streakInfo,
          );
        }
      }

      // Check achievements
      await _achievementService.checkAndAward(uid, 'watch');

      // Track campaigns
      await _campaignService.onReelWatched(uid);

      // Track series progress
      if (reelId != null) {
        final seriesResult = await _seriesService.onReelWatched(uid, reelId);
        if (seriesResult != null) {
          result['series'] = seriesResult;
        }
      }
    }

    result['newTotal'] = newTotal;
    return result;
  }

  /// Add bonus points directly to available balance (not locked).
  /// Used for streak milestones, achievements, campaign rewards.
  Future<void> addBonusPoints(int amount, String uid, String reason) async {
    final txn = TransactionModel(
      id: _uuid.v4(),
      uid: uid,
      type: 'bonus',
      amount: amount,
      reason: reason,
    );
    await _firestoreService.addTransaction(txn);
    await _firestoreService.updatePointsBalance(uid, amount);

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_pointsKey) ?? 0;
    await prefs.setInt(_pointsKey, current + amount);
  }

  /// Redeem points — check suspended status
  Future<bool> redeemPoints(int amount, String uid, String reason) async {
    // Suspended users cannot redeem
    final user = await _firestoreService.getUser(uid);
    if (user == null || user.accountStatus != 'active') {
      throw Exception('Account is not active — cannot redeem points');
    }

    // Check balance from Firestore (single source of truth)
    if (user.pointsBalance < amount) return false;

    // Update Firestore first
    final txn = TransactionModel(
      id: _uuid.v4(),
      uid: uid,
      type: 'redeemed',
      amount: amount,
      reason: reason,
    );
    await _firestoreService.addTransaction(txn);
    await _firestoreService.updatePointsBalance(uid, -amount);

    // Sync local cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pointsKey, user.pointsBalance - amount);

    return true;
  }

  /// Get completed reels for a specific user.
  /// Falls back to the legacy (non-user-specific) key and migrates data.
  Future<Set<String>> getCompletedReels({String? uid}) async {
    final prefs = await SharedPreferences.getInstance();
    if (uid != null && uid.isNotEmpty) {
      final userKey = '$_completedReelsKeyPrefix$uid';
      var list = prefs.getStringList(userKey);
      if (list == null) {
        // Migrate legacy data (one-time)
        // ignore: deprecated_member_use_from_same_package
        final legacy = prefs.getStringList(_completedReelsKeyLegacy) ?? [];
        if (legacy.isNotEmpty) {
          await prefs.setStringList(userKey, legacy);
        }
        list = legacy;
      }
      return list.toSet();
    }
    // Fallback for no uid
    // ignore: deprecated_member_use_from_same_package
    final list = prefs.getStringList(_completedReelsKeyLegacy) ?? [];
    return list.toSet();
  }

  Future<bool> isReelCompleted(String reelId, {String? uid}) async {
    // Check Firestore first for authoritative answer
    if (uid != null && uid.isNotEmpty) {
      final doc = await FirebaseFirestore.instance
          .collection('reelWatchRewards')
          .doc('${uid}_$reelId')
          .get();
      if (doc.exists) return true;
    }
    final completed = await getCompletedReels(uid: uid);
    return completed.contains(reelId);
  }

  /// Mark a reel as completed for a specific user (local + Firestore).
  Future<void> markReelCompleted(String reelId, {String? uid}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = (uid != null && uid.isNotEmpty)
        ? '$_completedReelsKeyPrefix$uid'
        // ignore: deprecated_member_use_from_same_package
        : _completedReelsKeyLegacy;
    final list = prefs.getStringList(key) ?? [];
    final set = list.toSet();
    set.add(reelId);
    await prefs.setStringList(key, set.toList());

    // Also record in Firestore for server-side dedup
    if (uid != null && uid.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('reelWatchRewards')
          .doc('${uid}_$reelId')
          .set({
        'uid': uid,
        'reelId': reelId,
        'rewardedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<bool> canEarnPoints(String uid) async {
    // Check suspended
    final user = await _firestoreService.getUser(uid);
    if (user == null || user.accountStatus != 'active') return false;
    return !(await _fraudService.hasReachedDailyCap(uid));
  }

  Future<List<TransactionModel>> getTransactionHistory(String uid) async {
    return await _firestoreService.getUserTransactions(uid);
  }

  /// Transfer points from sender to receiver with a 10% fee (ceiling).
  /// Uses Firestore batch for atomic deduct+credit.
  /// Returns the net amount received, or throws on failure.
  Future<int> transferPoints(String senderUid, String receiverUid, int amount) async {
    if (senderUid == receiverUid) {
      throw Exception('Cannot transfer points to yourself');
    }
    if (amount <= 0) {
      throw Exception('Transfer amount must be positive');
    }

    // Verify sender account is active
    final sender = await _firestoreService.getUser(senderUid);
    if (sender == null || sender.accountStatus != 'active') {
      throw Exception('Your account is not active');
    }

    // Verify receiver exists and is active
    final receiver = await _firestoreService.getUser(receiverUid);
    if (receiver == null || receiver.accountStatus != 'active') {
      throw Exception('Recipient account is not active or does not exist');
    }

    // Check sender balance from Firestore (single source of truth)
    if (sender.pointsBalance < amount) {
      throw Exception('Insufficient points balance. You have ${sender.pointsBalance} pts.');
    }

    // Calculate fee (10%, rounded up)
    final fee = (amount * 0.10).ceil();
    final netAmount = amount - fee;

    // Use Firestore WriteBatch for atomic transfer
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // Deduct from sender
      batch.update(db.collection('users').doc(senderUid), {
        'pointsBalance': FieldValue.increment(-amount),
      });

      // Credit to receiver
      batch.update(db.collection('users').doc(receiverUid), {
        'pointsBalance': FieldValue.increment(netAmount),
      });

      // Log sender transaction (deduction)
      final senderTxn = TransactionModel(
        id: _uuid.v4(),
        uid: senderUid,
        type: 'redeemed',
        amount: amount,
        reason: 'Transfer to @${receiver.username}',
      );
      batch.set(
        db.collection('transactions').doc(senderTxn.id),
        senderTxn.toMap(),
      );

      // Log receiver transaction (credit)
      final receiverTxn = TransactionModel(
        id: _uuid.v4(),
        uid: receiverUid,
        type: 'bonus',
        amount: netAmount,
        reason: 'Transfer from @${sender.username}',
      );
      batch.set(
        db.collection('transactions').doc(receiverTxn.id),
        receiverTxn.toMap(),
      );

      // Log the transfer record
      final transfer = PointTransferModel(
        id: _uuid.v4(),
        senderId: senderUid,
        receiverId: receiverUid,
        grossAmount: amount,
        fee: fee,
        netAmount: netAmount,
      );
      batch.set(
        db.collection('pointTransfers').doc(transfer.id),
        transfer.toMap(),
      );

      // Create notification for the receiver
      final notif = NotificationModel(
        id: _uuid.v4(),
        toUid: receiverUid,
        fromUid: senderUid,
        type: 'points',
        message: 'sent you $netAmount points',
      );
      batch.set(
        db.collection('notifications').doc(notif.id),
        notif.toMap(),
      );

      // Commit all operations atomically
      await batch.commit();

      // Sync local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_pointsKey, sender.pointsBalance - amount);

      return netAmount;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }
}

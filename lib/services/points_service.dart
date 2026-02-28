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

class PointsService {
  static const String _pointsKey = 'total_points';
  static const String _completedReelsKey = 'completed_reels';
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

  Future<int> getPoints() async {
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

      // Points go to lockedPoints (unlocked after 24h by Cloud Function)
      await _firestoreService.updateUser(uid, {
        'lockedPoints': FieldValue.increment(amount),
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

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_pointsKey) ?? 0;
    if (current < amount) return false;

    final newTotal = current - amount;
    await prefs.setInt(_pointsKey, newTotal);

    final txn = TransactionModel(
      id: _uuid.v4(),
      uid: uid,
      type: 'redeemed',
      amount: amount,
      reason: reason,
    );
    await _firestoreService.addTransaction(txn);
    await _firestoreService.updatePointsBalance(uid, -amount);

    return true;
  }

  Future<Set<String>> getCompletedReels() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_completedReelsKey) ?? [];
    return list.toSet();
  }

  Future<bool> isReelCompleted(String reelId) async {
    final completed = await getCompletedReels();
    return completed.contains(reelId);
  }

  Future<void> markReelCompleted(String reelId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_completedReelsKey) ?? [];
    final set = list.toSet();
    set.add(reelId);
    await prefs.setStringList(_completedReelsKey, set.toList());
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
      throw Exception('Recipient account is not active');
    }

    // Check sender balance
    final prefs = await SharedPreferences.getInstance();
    final currentBalance = prefs.getInt(_pointsKey) ?? 0;
    if (currentBalance < amount) {
      throw Exception('Insufficient points balance');
    }

    // Calculate fee (10%, rounded up)
    final fee = (amount * 0.10).ceil();
    final netAmount = amount - fee;

    // Deduct from sender
    final deducted = await redeemPoints(amount, senderUid, 'Transfer to @${receiver.username}');
    if (!deducted) {
      throw Exception('Failed to deduct points');
    }

    // Credit to receiver
    await addBonusPoints(netAmount, receiverUid, 'Transfer from @${sender.username}');

    // Log the transfer
    final transfer = PointTransferModel(
      id: _uuid.v4(),
      senderId: senderUid,
      receiverId: receiverUid,
      grossAmount: amount,
      fee: fee,
      netAmount: netAmount,
    );
    await _firestoreService.logPointTransfer(transfer);

    // Create notification for the receiver
    final notif = NotificationModel(
      id: _uuid.v4(),
      toUid: receiverUid,
      fromUid: senderUid,
      type: 'points',
      message: 'sent you $netAmount points',
    );
    await _firestoreService.addNotification(notif);

    return netAmount;
  }
}

import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import 'firestore_service.dart';
import 'fraud_service.dart';

class PointsService {
  static const String _pointsKey = 'total_points';
  static const String _completedReelsKey = 'completed_reels';
  static const int dailyEarningCap = 100;
  static final _random = Random();
  final _uuid = const Uuid();

  final FirestoreService _firestoreService = FirestoreService();
  final FraudService _fraudService = FraudService();

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

  /// Add points — with suspension and private reel checks
  Future<int> addPoints(int amount, {String? uid, String? reelId}) async {
    // Check if user is suspended — no rewards
    if (uid != null) {
      final user = await _firestoreService.getUser(uid);
      if (user == null || user.accountStatus != 'active') {
        throw Exception('Account is not active — cannot earn points');
      }
    }

    // Check if reel is private — no rewards for private reels
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

    // Log transaction to Firestore
    if (uid != null) {
      final txn = TransactionModel(
        id: _uuid.v4(),
        uid: uid,
        type: 'earned',
        amount: amount,
        reason: 'Watched reel to completion',
        reelId: reelId ?? '',
      );
      await _firestoreService.addTransaction(txn);
      await _firestoreService.updatePointsBalance(uid, amount);
    }

    return newTotal;
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
}

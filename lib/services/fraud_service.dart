import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';

class FraudService {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int maxDailyEarnings = 100;
  static const int maxReelsPerHour = 30;
  static const int minWatchSeconds = 5; // Minimum realistic watch time
  static const int maxDevices = 5;       // Max devices per account

  /// Check if user has reached daily earning cap
  Future<bool> hasReachedDailyCap(String uid) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final snap = await _db
        .collection('transactions')
        .where('uid', isEqualTo: uid)
        .where('type', isEqualTo: 'earned')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();
    int totalToday = 0;
    for (final doc in snap.docs) {
      totalToday += (doc.data()['amount'] as int?) ?? 0;
    }
    return totalToday >= maxDailyEarnings;
  }

  /// Validate a watch attempt — comprehensive fraud checks
  Future<bool> validateWatch(String uid, String reelId, double completionRate) async {
    // Check daily cap
    if (await hasReachedDailyCap(uid)) return false;

    // Minimum 90% completion (changed from 95% for flexibility)
    if (completionRate < 0.90) return false;

    // Rate limit: max reels per hour
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    final recentSnap = await _db
        .collection('transactions')
        .where('uid', isEqualTo: uid)
        .where('type', isEqualTo: 'earned')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(oneHourAgo))
        .get();
    if (recentSnap.docs.length >= maxReelsPerHour) return false;

    // Account status check
    final user = await _firestoreService.getUser(uid);
    if (user == null || user.accountStatus != 'active') return false;

    return true;
  }

  /// Detect suspiciously fast reel completion (bot-like behavior)
  Future<bool> detectFastCompletion(String uid, int actualWatchSeconds, int reelDurationSeconds) async {
    // If someone "watches" a 60-second reel in < 5 seconds, it's suspicious
    if (reelDurationSeconds > 10 && actualWatchSeconds < minWatchSeconds) {
      await _flagAccount(uid, 'fast_completion');
      return true;
    }
    return false;
  }

  /// Detect multi-device abuse
  Future<bool> detectMultiDevice(String uid) async {
    final user = await _firestoreService.getUser(uid);
    if (user == null) return false;
    if (user.deviceIds.length > maxDevices) {
      await _flagAccount(uid, 'multi_device');
      return true;
    }
    return false;
  }

  /// Detect repeated watch attempts on same reel
  Future<bool> detectRepeatedWatch(String uid, String reelId) async {
    final snap = await _db
        .collection('transactions')
        .where('uid', isEqualTo: uid)
        .where('reelId', isEqualTo: reelId)
        .get();
    if (snap.docs.length > 1) {
      return true; // Already earned from this reel
    }
    return false;
  }

  /// Flag account for suspicious activity
  Future<void> _flagAccount(String uid, String reason) async {
    await _db.collection('fraud_flags').add({
      'uid': uid,
      'reason': reason,
      'createdAt': Timestamp.now(),
      'resolved': false,
    });
    debugPrint('⚠️ Fraud flag: $reason for user $uid');
  }

  /// Flag account (public method for admin use)
  Future<void> flagAccount(String uid, String reason) async {
    await _flagAccount(uid, reason);
  }

  /// Disable rewards for a user
  Future<void> disableRewards(String uid) async {
    await _firestoreService.updateUser(uid, {
      'rewardsEnabled': false,
    });
  }

  /// Freeze wallet — disallow redemptions
  Future<void> freezeWallet(String uid) async {
    await _firestoreService.updateUser(uid, {
      'walletFrozen': true,
    });
  }

  /// Unfreeze wallet
  Future<void> unfreezeWallet(String uid) async {
    await _firestoreService.updateUser(uid, {
      'walletFrozen': false,
    });
  }

  /// Suspend account (escalation from fraud detection)
  Future<void> suspendAccount(String uid) async {
    await _firestoreService.updateUser(uid, {
      'accountStatus': 'suspended',
    });
    await freezeWallet(uid);
    await disableRewards(uid);
  }

  /// Get fraud flags for a user
  Future<List<Map<String, dynamic>>> getFraudFlags(String uid) async {
    final snap = await _db
        .collection('fraud_flags')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  /// Get all unresolved fraud flags (for admin)
  Future<List<Map<String, dynamic>>> getUnresolvedFlags() async {
    final snap = await _db
        .collection('fraud_flags')
        .where('resolved', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }
}

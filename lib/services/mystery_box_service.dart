import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class MysteryBoxService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final _random = Random();

  static const int boxCost = 50;
  static const int maxBoxesPerDay = 3;

  // Reward tiers: {label, value, weight}
  static const List<Map<String, dynamic>> _rewardTiers = [
    {'label': '5 Points', 'value': 5, 'weight': 40},
    {'label': '15 Points', 'value': 15, 'weight': 25},
    {'label': '30 Points', 'value': 30, 'weight': 15},
    {'label': '75 Points', 'value': 75, 'weight': 10},
    {'label': '150 Points', 'value': 150, 'weight': 5},
    {'label': 'Special Reward', 'value': 200, 'weight': 5},
  ];

  /// Opens a mystery box. Tries Cloud Function first, falls back to client-side.
  Future<Map<String, dynamic>?> openBox(String uid) async {
    // Try Cloud Function first
    try {
      final callable = _functions.httpsCallable('openMysteryBox');
      final result = await callable
          .call({'uid': uid})
          .timeout(const Duration(seconds: 8));
      return Map<String, dynamic>.from(result.data as Map);
    } catch (_) {
      // Cloud Function unavailable — run client-side fallback
    }

    return _openBoxClientSide(uid);
  }

  /// Client-side mystery box logic (fallback when Cloud Functions not deployed).
  Future<Map<String, dynamic>?> _openBoxClientSide(String uid) async {
    try {
      // Verify balance
      final userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) return null;
      final balance = (userDoc.data()?['pointsBalance'] ?? 0) as int;
      if (balance < boxCost) return null;

      // Verify daily limit
      if (!(await canOpenBox(uid))) return null;

      // Pick reward using weighted random
      final reward = _pickReward();
      final rewardValue = reward['value'] as int;
      final rewardLabel = reward['label'] as String;

      // Deduct cost and add reward atomically
      final netChange = rewardValue - boxCost;
      await _db.collection('users').doc(uid).update({
        'pointsBalance': FieldValue.increment(netChange),
      });

      // Record result
      final resultDoc = _db.collection('mysteryBoxResults').doc();
      await resultDoc.set({
        'uid': uid,
        'rewardLabel': rewardLabel,
        'rewardValue': rewardValue,
        'cost': boxCost,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Record transaction
      await _db.collection('transactions').add({
        'uid': uid,
        'type': 'bonus',
        'amount': rewardValue,
        'reason': 'Mystery Box: $rewardLabel',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return {
        'rewardLabel': rewardLabel,
        'rewardValue': rewardValue,
        'cost': boxCost,
      };
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _pickReward() {
    final totalWeight = _rewardTiers.fold<int>(
        0, (s, t) => s + (t['weight'] as int));
    var roll = _random.nextInt(totalWeight);
    for (final tier in _rewardTiers) {
      roll -= tier['weight'] as int;
      if (roll < 0) return tier;
    }
    return _rewardTiers.first;
  }

  Future<bool> canOpenBox(String uid) async {
    // Check balance
    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists) return false;
    final balance = userDoc.data()?['pointsBalance'] ?? 0;
    if (balance < boxCost) return false;

    // Check daily limit
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final snap = await _db
        .collection('mysteryBoxResults')
        .where('uid', isEqualTo: uid)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .get();
    return snap.docs.length < maxBoxesPerDay;
  }

  Future<List<Map<String, dynamic>>> getHistory(String uid) async {
    final snap = await _db
        .collection('mysteryBoxResults')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }
}

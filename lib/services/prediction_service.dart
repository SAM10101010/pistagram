import 'package:cloud_firestore/cloud_firestore.dart';

class PredictionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _predictions =>
      _db.collection('predictions');

  static const int maxPredictionsPerDay = 3;

  static const Map<String, Map<String, dynamic>> predictionTypes = {
    'likes_10k': {
      'label': 'Will this reel hit 10K likes?',
      'threshold': 10000,
      'field': 'likesCount',
      'reward': 15,
    },
    'views_50k': {
      'label': 'Will this reel reach 50K views?',
      'threshold': 50000,
      'field': 'viewsCount',
      'reward': 10,
    },
    'rating_4plus': {
      'label': 'Will this reel be rated 4+?',
      'threshold': 4,
      'field': 'averageRating',
      'reward': 20,
    },
  };

  Future<bool> makePrediction(
    String uid,
    String reelId,
    String type,
    bool prediction,
  ) async {
    final docId = '${uid}_$reelId';
    final existing = await _predictions.doc(docId).get();
    if (existing.exists) return false;

    // Daily limit
    if (await _hasReachedDailyLimit(uid)) return false;

    await _predictions.doc(docId).set({
      'uid': uid,
      'reelId': reelId,
      'predictionType': type,
      'prediction': prediction,
      'resolved': false,
      'correct': null,
      'bonusAwarded': 0,
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'resolvedAt': null,
    });

    return true;
  }

  Future<Map<String, dynamic>?> getUserPrediction(
    String uid,
    String reelId,
  ) async {
    final docId = '${uid}_$reelId';
    final doc = await _predictions.doc(docId).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<List<Map<String, dynamic>>> getUnresolvedPredictions(
    String uid,
  ) async {
    final snap = await _predictions
        .where('uid', isEqualTo: uid)
        .where('resolved', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<List<Map<String, dynamic>>> getAllPredictions(String uid) async {
    final snap = await _predictions
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<bool> _hasReachedDailyLimit(String uid) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final snap = await _predictions
        .where('uid', isEqualTo: uid)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .get();
    return snap.docs.length >= maxPredictionsPerDay;
  }
}

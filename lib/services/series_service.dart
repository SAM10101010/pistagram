import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/series_model.dart';
import '../models/transaction_model.dart';
import '../models/notification_model.dart';
import 'firestore_service.dart';

class SeriesService {
  final FirestoreService _firestore = FirestoreService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _series =>
      _db.collection('series');
  CollectionReference<Map<String, dynamic>> get _progress =>
      _db.collection('seriesProgress');

  Future<void> createSeries(SeriesModel series) async {
    await _series.doc(series.seriesId).set(series.toMap());
  }

  Future<List<SeriesModel>> getSeriesByCreator(String uid) async {
    final snap = await _series
        .where('creatorUid', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => SeriesModel.fromMap(d.data())).toList();
  }

  Future<List<SeriesModel>> getActiveSeries({int limit = 20}) async {
    final snap = await _series
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => SeriesModel.fromMap(d.data())).toList();
  }

  Future<SeriesModel?> getSeries(String seriesId) async {
    final doc = await _series.doc(seriesId).get();
    if (!doc.exists) return null;
    return SeriesModel.fromMap(doc.data()!);
  }

  Future<SeriesProgressModel?> getProgress(String uid, String seriesId) async {
    final docId = '${uid}_$seriesId';
    final doc = await _progress.doc(docId).get();
    if (!doc.exists) return null;
    return SeriesProgressModel.fromMap(doc.data()!);
  }

  /// Called when a reel is watched. Checks all active series containing this reel.
  Future<Map<String, dynamic>?> onReelWatched(String uid, String reelId) async {
    // Find all series containing this reel
    final snap = await _series
        .where('reelIds', arrayContains: reelId)
        .where('isActive', isEqualTo: true)
        .get();

    for (final doc in snap.docs) {
      final series = SeriesModel.fromMap(doc.data());
      final docId = '${uid}_${series.seriesId}';
      final progressDoc = await _progress.doc(docId).get();

      if (progressDoc.exists) {
        final data = progressDoc.data()!;
        if (data['completed'] == true) continue;

        final watched = List<String>.from(data['watchedReelIds'] ?? []);
        if (watched.contains(reelId)) continue;

        watched.add(reelId);
        final isComplete = watched.length >= series.reelIds.length;

        await _progress.doc(docId).update({
          'watchedReelIds': FieldValue.arrayUnion([reelId]),
          if (isComplete) 'completed': true,
          if (isComplete) 'completedAt': Timestamp.fromDate(DateTime.now()),
        });

        if (isComplete) {
          return await _awardSeriesBonus(uid, series);
        }
      } else {
        final isComplete = series.reelIds.length <= 1;
        await _progress
            .doc(docId)
            .set(
              SeriesProgressModel(
                uid: uid,
                seriesId: series.seriesId,
                watchedReelIds: [reelId],
                completed: isComplete,
                completedAt: isComplete ? DateTime.now() : null,
              ).toMap(),
            );

        if (isComplete) {
          return await _awardSeriesBonus(uid, series);
        }
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _awardSeriesBonus(
    String uid,
    SeriesModel series,
  ) async {
    final docId = '${uid}_${series.seriesId}';
    final progressDoc = await _progress.doc(docId).get();
    if (progressDoc.data()?['bonusAwarded'] == true) {
      return {'seriesTitle': series.title, 'bonus': 0, 'alreadyAwarded': true};
    }

    // Award bonus
    final txn = TransactionModel(
      id: _uuid.v4(),
      uid: uid,
      type: 'bonus',
      amount: series.bonusPoints,
      reason: 'Completed series: ${series.title}',
    );
    await _firestore.addTransaction(txn);
    await _firestore.updatePointsBalance(uid, series.bonusPoints);
    await _progress.doc(docId).update({'bonusAwarded': true});

    await _firestore.addNotification(
      NotificationModel(
        id: _uuid.v4(),
        toUid: uid,
        fromUid: uid,
        type: 'series',
        message:
            'You completed "${series.title}"! +${series.bonusPoints} bonus points!',
      ),
    );

    return {
      'seriesTitle': series.title,
      'bonus': series.bonusPoints,
      'alreadyAwarded': false,
    };
  }

  Future<void> addReelToSeries(String seriesId, String reelId) async {
    await _series.doc(seriesId).update({
      'reelIds': FieldValue.arrayUnion([reelId]),
      'totalReels': FieldValue.increment(1),
    });
  }

  /// Find series containing a given reel
  Future<List<SeriesModel>> getSeriesForReel(String reelId) async {
    final snap = await _series
        .where('reelIds', arrayContains: reelId)
        .where('isActive', isEqualTo: true)
        .get();
    return snap.docs.map((d) => SeriesModel.fromMap(d.data())).toList();
  }
}

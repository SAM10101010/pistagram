import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/campaign_model.dart';
import '../models/transaction_model.dart';
import '../models/notification_model.dart';
import 'firestore_service.dart';

class CampaignService {
  final FirestoreService _firestore = FirestoreService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _campaigns =>
      _db.collection('campaigns');
  CollectionReference<Map<String, dynamic>> get _progress =>
      _db.collection('campaignProgress');

  Future<List<CampaignModel>> getActiveCampaigns() async {
    final now = DateTime.now();
    final snap = await _campaigns
        .where('isActive', isEqualTo: true)
        .where('endTime', isGreaterThan: Timestamp.fromDate(now))
        .get();
    return snap.docs
        .map((d) => CampaignModel.fromMap(d.data()))
        .where((c) => c.isLive)
        .toList();
  }

  Future<CampaignProgressModel?> getUserProgress(
    String uid,
    String campaignId,
  ) async {
    final docId = '${uid}_$campaignId';
    final doc = await _progress.doc(docId).get();
    if (!doc.exists) return null;
    return CampaignProgressModel.fromMap(doc.data()!);
  }

  Future<void> incrementProgress(
    String uid,
    String campaignId, {
    int amount = 1,
  }) async {
    final docId = '${uid}_$campaignId';
    final doc = await _progress.doc(docId).get();

    if (!doc.exists) {
      await _progress
          .doc(docId)
          .set(
            CampaignProgressModel(
              uid: uid,
              campaignId: campaignId,
              currentProgress: amount,
            ).toMap(),
          );
    } else {
      final data = doc.data()!;
      if (data['completed'] == true) return;
      await _progress.doc(docId).update({
        'currentProgress': FieldValue.increment(amount),
      });
    }

    // Check completion
    final campaign = await _getCampaign(campaignId);
    if (campaign == null) return;

    final updated = await _progress.doc(docId).get();
    final progress = updated.data()?['currentProgress'] ?? 0;
    if (progress >= campaign.conditionValue &&
        updated.data()?['completed'] != true) {
      await _progress.doc(docId).update({
        'completed': true,
        'completedAt': Timestamp.fromDate(DateTime.now()),
      });

      await _firestore.addNotification(
        NotificationModel(
          id: _uuid.v4(),
          toUid: uid,
          fromUid: uid,
          type: 'campaign',
          message: 'Campaign completed: ${campaign.title}! Claim your reward.',
        ),
      );
    }
  }

  /// Track reel watch for all active campaigns of type 'watch_count'
  Future<void> onReelWatched(String uid) async {
    final campaigns = await getActiveCampaigns();
    for (final campaign in campaigns) {
      if (campaign.conditionType == 'watch_count') {
        await incrementProgress(uid, campaign.campaignId);
      }
    }
  }

  Future<bool> claimReward(String uid, String campaignId) async {
    final docId = '${uid}_$campaignId';
    final doc = await _progress.doc(docId).get();
    if (!doc.exists) return false;

    final data = doc.data()!;
    if (data['completed'] != true || data['rewardClaimed'] == true)
      return false;

    final campaign = await _getCampaign(campaignId);
    if (campaign == null) return false;

    // Award points
    final txn = TransactionModel(
      id: _uuid.v4(),
      uid: uid,
      type: 'bonus',
      amount: campaign.rewardPoints,
      reason: 'Campaign reward: ${campaign.title}',
    );
    await _firestore.addTransaction(txn);
    await _firestore.updatePointsBalance(uid, campaign.rewardPoints);

    await _progress.doc(docId).update({'rewardClaimed': true});

    return true;
  }

  Future<CampaignModel?> _getCampaign(String campaignId) async {
    final doc = await _campaigns.doc(campaignId).get();
    if (!doc.exists) return null;
    return CampaignModel.fromMap(doc.data()!);
  }

  // Admin methods
  Future<void> createCampaign(CampaignModel campaign) async {
    await _campaigns.doc(campaign.campaignId).set(campaign.toMap());
  }

  Future<void> updateCampaign(String id, Map<String, dynamic> data) async {
    await _campaigns.doc(id).update(data);
  }

  Future<List<CampaignModel>> getAllCampaigns() async {
    final snap = await _campaigns.orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => CampaignModel.fromMap(d.data())).toList();
  }
}

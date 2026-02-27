import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

export const checkCampaignCompletion = functions.firestore
  .document('transactions/{txnId}')
  .onCreate(async (snap) => {
    const txnData = snap.data();
    const uid = txnData.uid;
    if (!uid || txnData.type !== 'earned') return;

    const now = admin.firestore.Timestamp.now();

    // Get active campaigns
    const campaignsSnap = await db.collection('campaigns')
      .where('isActive', '==', true)
      .where('endTime', '>', now)
      .get();

    for (const campaignDoc of campaignsSnap.docs) {
      const campaign = campaignDoc.data();
      const progressId = `${uid}_${campaignDoc.id}`;
      const progressRef = db.collection('campaignProgress').doc(progressId);
      const progressSnap = await progressRef.get();

      if (progressSnap.exists && progressSnap.data()?.completed) continue;

      const currentProgress = progressSnap.exists
        ? (progressSnap.data()?.currentProgress || 0)
        : 0;

      let increment = 0;
      switch (campaign.conditionType) {
        case 'watch_count':
          increment = 1;
          break;
        case 'earn_points':
          increment = txnData.amount || 0;
          break;
        case 'like_count':
          if (txnData.reason?.includes('like')) increment = 1;
          break;
        default:
          break;
      }

      if (increment <= 0) continue;

      const newProgress = currentProgress + increment;
      const completed = newProgress >= campaign.conditionValue;

      await progressRef.set({
        uid,
        campaignId: campaignDoc.id,
        currentProgress: newProgress,
        completed,
        rewardClaimed: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
  });

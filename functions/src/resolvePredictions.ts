import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

export const resolvePredictions = functions.pubsub
  .schedule('0 1 * * *')
  .timeZone('UTC')
  .onRun(async () => {
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    const snap = await db.collection('predictions')
      .where('resolved', '==', false)
      .where('createdAt', '<=', admin.firestore.Timestamp.fromDate(sevenDaysAgo))
      .get();

    let resolved = 0;

    for (const doc of snap.docs) {
      const data = doc.data();
      const reelId = data.reelId;
      const prediction = data.prediction as boolean;
      const predictionType = data.predictionType as string;

      // Get current reel stats
      const reelDoc = await db.collection('reels').doc(reelId).get();
      if (!reelDoc.exists) continue;
      const reel = reelDoc.data()!;

      let actual = false;
      switch (predictionType) {
        case 'likes_10k':
          actual = (reel.likesCount || 0) >= 10000;
          break;
        case 'views_50k':
          actual = (reel.viewsCount || 0) >= 50000;
          break;
        case 'rating_4plus':
          actual = (reel.averageRating || 0) >= 4.0;
          break;
      }

      const correct = prediction === actual;
      const bonusPoints = correct ? (predictionType === 'likes_10k' ? 20 : 10) : 0;

      await doc.ref.update({
        resolved: true,
        correct,
        bonusPoints,
        resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Award bonus points if correct
      if (correct && bonusPoints > 0) {
        const uid = data.uid;
        await db.collection('users').doc(uid).update({
          pointsBalance: admin.firestore.FieldValue.increment(bonusPoints),
        });

        // Create transaction record
        await db.collection('transactions').add({
          uid,
          type: 'bonus',
          amount: bonusPoints,
          reason: `Correct prediction: ${predictionType}`,
          reelId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      resolved++;
    }

    console.log(`Resolved ${resolved} predictions`);
  });

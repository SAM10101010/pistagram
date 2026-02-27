import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

export const expireReels = functions.pubsub
  .schedule('0 * * * *')
  .timeZone('UTC')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();

    const snap = await db.collection('reels')
      .where('isActive', '==', true)
      .where('expiryTime', '<=', now)
      .get();

    if (snap.empty) {
      console.log('No reels to expire');
      return;
    }

    const batches: admin.firestore.WriteBatch[] = [];
    let batch = db.batch();
    let count = 0;

    for (const doc of snap.docs) {
      batch.update(doc.ref, { isActive: false });
      count++;
      if (count % 500 === 0) {
        batches.push(batch);
        batch = db.batch();
      }
    }

    if (count % 500 !== 0) batches.push(batch);
    await Promise.all(batches.map(b => b.commit()));
    console.log(`Expired ${count} reels`);
  });

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

export const expireBoosts = functions.pubsub
  .schedule('30 * * * *')
  .timeZone('UTC')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();

    const snap = await db.collection('boostedReels')
      .where('boostExpiry', '<=', now)
      .get();

    if (snap.empty) {
      console.log('No boosts to expire');
      return;
    }

    const batches: admin.firestore.WriteBatch[] = [];
    let batch = db.batch();
    let count = 0;

    for (const doc of snap.docs) {
      batch.delete(doc.ref);
      count++;
      if (count % 500 === 0) {
        batches.push(batch);
        batch = db.batch();
      }
    }

    if (count % 500 !== 0) batches.push(batch);
    await Promise.all(batches.map(b => b.commit()));
    console.log(`Removed ${count} expired boosts`);
  });

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

export const unlockPoints = functions.pubsub
  .schedule('5 0 * * *')
  .timeZone('UTC')
  .onRun(async () => {
    const snap = await db.collection('users')
      .where('lockedPoints', '>', 0)
      .get();

    const batches: admin.firestore.WriteBatch[] = [];
    let batch = db.batch();
    let count = 0;

    for (const doc of snap.docs) {
      const data = doc.data();
      const locked = data.lockedPoints || 0;
      const current = data.pointsBalance || 0;

      batch.update(doc.ref, {
        pointsBalance: current + locked,
        lockedPoints: 0,
        lastLockReset: admin.firestore.FieldValue.serverTimestamp(),
      });

      count++;
      if (count % 500 === 0) {
        batches.push(batch);
        batch = db.batch();
      }
    }

    if (count % 500 !== 0) batches.push(batch);

    await Promise.all(batches.map(b => b.commit()));
    console.log(`Unlocked points for ${count} users`);
  });

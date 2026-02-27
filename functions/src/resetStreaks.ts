import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

export const resetStreaks = functions.pubsub
  .schedule('10 0 * * *')
  .timeZone('UTC')
  .onRun(async () => {
    const now = new Date();
    const yesterday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);

    // Reset streakReelsToday for all users
    const allUsersSnap = await db.collection('users')
      .where('streakReelsToday', '>', 0)
      .get();

    const batches: admin.firestore.WriteBatch[] = [];
    let batch = db.batch();
    let count = 0;

    for (const doc of allUsersSnap.docs) {
      const data = doc.data();
      const lastStreakDate = data.lastStreakDate?.toDate?.() || null;

      const updates: Record<string, any> = {
        streakReelsToday: 0,
      };

      // If last streak date is before yesterday, streak is broken
      if (lastStreakDate && lastStreakDate < yesterday) {
        updates.streakCount = 0;
      }

      batch.update(doc.ref, updates);
      count++;
      if (count % 500 === 0) {
        batches.push(batch);
        batch = db.batch();
      }
    }

    if (count % 500 !== 0) batches.push(batch);
    await Promise.all(batches.map(b => b.commit()));
    console.log(`Reset streaks for ${count} users`);
  });

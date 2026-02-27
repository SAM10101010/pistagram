import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

export const recalculateLeaderboard = functions.pubsub
  .schedule('15 0 * * 1')
  .timeZone('UTC')
  .onRun(async () => {
    const now = new Date();
    const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    // Weekly leaderboard
    await calculateLeaderboard(
      'leaderboardWeekly',
      admin.firestore.Timestamp.fromDate(weekAgo)
    );

    // Monthly leaderboard (always recalculate)
    await calculateLeaderboard(
      'leaderboardMonthly',
      admin.firestore.Timestamp.fromDate(monthStart)
    );

    console.log('Leaderboard recalculated');
  });

async function calculateLeaderboard(
  collection: string,
  since: admin.firestore.Timestamp
) {
  const txnSnap = await db.collection('transactions')
    .where('type', '==', 'earned')
    .where('createdAt', '>=', since)
    .get();

  const userPoints: Record<string, number> = {};
  for (const doc of txnSnap.docs) {
    const data = doc.data();
    const uid = data.uid || '';
    const amount = data.amount || 0;
    userPoints[uid] = (userPoints[uid] || 0) + amount;
  }

  // Clear existing
  const existingSnap = await db.collection(collection).get();
  const clearBatch = db.batch();
  existingSnap.docs.forEach(doc => clearBatch.delete(doc.ref));
  await clearBatch.commit();

  // Write new entries
  const sorted = Object.entries(userPoints)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 100);

  const batches: admin.firestore.WriteBatch[] = [];
  let batch = db.batch();
  let count = 0;

  for (const [uid, points] of sorted) {
    const userDoc = await db.collection('users').doc(uid).get();
    const userData = userDoc.data();

    batch.set(db.collection(collection).doc(uid), {
      uid,
      points,
      username: userData?.username || '',
      displayName: userData?.displayName || '',
      profilePicUrl: userData?.profilePicUrl || '',
      rank: count + 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    count++;
    if (count % 500 === 0) {
      batches.push(batch);
      batch = db.batch();
    }
  }

  if (count % 500 !== 0) batches.push(batch);
  await Promise.all(batches.map(b => b.commit()));
}

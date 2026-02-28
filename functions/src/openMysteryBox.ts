import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const COST = 50;
const MAX_PER_DAY = 3;

interface RewardTier {
  probability: number;
  minReward: number;
  maxReward: number;
  label: string;
}

const tiers: RewardTier[] = [
  { probability: 0.40, minReward: 3, maxReward: 8, label: 'Common' },
  { probability: 0.25, minReward: 12, maxReward: 18, label: 'Uncommon' },
  { probability: 0.15, minReward: 25, maxReward: 35, label: 'Rare' },
  { probability: 0.10, minReward: 60, maxReward: 90, label: 'Epic' },
  { probability: 0.05, minReward: 120, maxReward: 180, label: 'Legendary' },
  { probability: 0.05, minReward: 200, maxReward: 300, label: 'Mythic' },
];

function getRandomReward(): { value: number; label: string } {
  const roll = Math.random();
  let cumulative = 0;

  for (const tier of tiers) {
    cumulative += tier.probability;
    if (roll <= cumulative) {
      const value = Math.floor(
        Math.random() * (tier.maxReward - tier.minReward + 1) + tier.minReward
      );
      return { value, label: tier.label };
    }
  }

  // Fallback to common
  return { value: 5, label: 'Common' };
}

export const openMysteryBox = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const uid = context.auth.uid;

  // Check rate limit
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);

  const todayBoxes = await db.collection('mysteryBoxResults')
    .where('uid', '==', uid)
    .where('openedAt', '>=', admin.firestore.Timestamp.fromDate(todayStart))
    .get();

  if (todayBoxes.size >= MAX_PER_DAY) {
    throw new functions.https.HttpsError('resource-exhausted', 'Daily limit reached (3 per day)');
  }

  // Check balance
  const userDoc = await db.collection('users').doc(uid).get();
  if (!userDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'User not found');
  }

  const balance = userDoc.data()?.pointsBalance || 0;
  if (balance < COST) {
    throw new functions.https.HttpsError('failed-precondition', 'Insufficient points');
  }

  // Generate reward
  const reward = getRandomReward();

  // Deduct cost and add reward atomically
  const netChange = reward.value - COST;
  await db.collection('users').doc(uid).update({
    pointsBalance: admin.firestore.FieldValue.increment(netChange),
  });

  // Record the transaction (cost)
  await db.collection('transactions').add({
    uid,
    type: 'redeemed',
    amount: COST,
    reason: 'Mystery Box opened',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Record the reward
  if (reward.value > 0) {
    await db.collection('transactions').add({
      uid,
      type: 'bonus',
      amount: reward.value,
      reason: `Mystery Box reward: ${reward.label}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // Record result
  const resultRef = await db.collection('mysteryBoxResults').add({
    uid,
    rewardType: reward.label.toLowerCase(),
    rewardValue: reward.value,
    rewardLabel: reward.label,
    openedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    rewardValue: reward.value,
    rewardLabel: reward.label,
    resultId: resultRef.id,
  };
});

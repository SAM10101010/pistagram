"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.recalculateLeaderboard = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
if (!admin.apps.length)
    admin.initializeApp();
const db = admin.firestore();
exports.recalculateLeaderboard = functions.pubsub
    .schedule('15 0 * * 1')
    .timeZone('UTC')
    .onRun(async () => {
    const now = new Date();
    const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    // Weekly leaderboard
    await calculateLeaderboard('leaderboardWeekly', admin.firestore.Timestamp.fromDate(weekAgo));
    // Monthly leaderboard (always recalculate)
    await calculateLeaderboard('leaderboardMonthly', admin.firestore.Timestamp.fromDate(monthStart));
    console.log('Leaderboard recalculated');
});
async function calculateLeaderboard(collection, since) {
    const txnSnap = await db.collection('transactions')
        .where('type', '==', 'earned')
        .where('createdAt', '>=', since)
        .get();
    const userPoints = {};
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
    const batches = [];
    let batch = db.batch();
    let count = 0;
    for (const [uid, points] of sorted) {
        const userDoc = await db.collection('users').doc(uid).get();
        const userData = userDoc.data();
        batch.set(db.collection(collection).doc(uid), {
            uid,
            points,
            username: (userData === null || userData === void 0 ? void 0 : userData.username) || '',
            displayName: (userData === null || userData === void 0 ? void 0 : userData.displayName) || '',
            profilePicUrl: (userData === null || userData === void 0 ? void 0 : userData.profilePicUrl) || '',
            rank: count + 1,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        count++;
        if (count % 500 === 0) {
            batches.push(batch);
            batch = db.batch();
        }
    }
    if (count % 500 !== 0)
        batches.push(batch);
    await Promise.all(batches.map(b => b.commit()));
}
//# sourceMappingURL=recalculateLeaderboard.js.map
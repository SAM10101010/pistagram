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
exports.resolvePredictions = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
if (!admin.apps.length)
    admin.initializeApp();
const db = admin.firestore();
exports.resolvePredictions = functions.pubsub
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
        const prediction = data.prediction;
        const predictionType = data.predictionType;
        // Get current reel stats
        const reelDoc = await db.collection('reels').doc(reelId).get();
        if (!reelDoc.exists)
            continue;
        const reel = reelDoc.data();
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
//# sourceMappingURL=resolvePredictions.js.map
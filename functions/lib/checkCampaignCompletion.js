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
exports.checkCampaignCompletion = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
if (!admin.apps.length)
    admin.initializeApp();
const db = admin.firestore();
exports.checkCampaignCompletion = functions.firestore
    .document('transactions/{txnId}')
    .onCreate(async (snap) => {
    var _a, _b, _c;
    const txnData = snap.data();
    const uid = txnData.uid;
    if (!uid || txnData.type !== 'earned')
        return;
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
        if (progressSnap.exists && ((_a = progressSnap.data()) === null || _a === void 0 ? void 0 : _a.completed))
            continue;
        const currentProgress = progressSnap.exists
            ? (((_b = progressSnap.data()) === null || _b === void 0 ? void 0 : _b.currentProgress) || 0)
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
                if ((_c = txnData.reason) === null || _c === void 0 ? void 0 : _c.includes('like'))
                    increment = 1;
                break;
            default:
                break;
        }
        if (increment <= 0)
            continue;
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
//# sourceMappingURL=checkCampaignCompletion.js.map
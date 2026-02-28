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
exports.resetStreaks = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
if (!admin.apps.length)
    admin.initializeApp();
const db = admin.firestore();
exports.resetStreaks = functions.pubsub
    .schedule('10 0 * * *')
    .timeZone('UTC')
    .onRun(async () => {
    var _a, _b;
    const now = new Date();
    const yesterday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
    // Reset streakReelsToday for all users
    const allUsersSnap = await db.collection('users')
        .where('streakReelsToday', '>', 0)
        .get();
    const batches = [];
    let batch = db.batch();
    let count = 0;
    for (const doc of allUsersSnap.docs) {
        const data = doc.data();
        const lastStreakDate = ((_b = (_a = data.lastStreakDate) === null || _a === void 0 ? void 0 : _a.toDate) === null || _b === void 0 ? void 0 : _b.call(_a)) || null;
        const updates = {
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
    if (count % 500 !== 0)
        batches.push(batch);
    await Promise.all(batches.map(b => b.commit()));
    console.log(`Reset streaks for ${count} users`);
});
//# sourceMappingURL=resetStreaks.js.map
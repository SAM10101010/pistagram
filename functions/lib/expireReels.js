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
exports.expireReels = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
if (!admin.apps.length)
    admin.initializeApp();
const db = admin.firestore();
exports.expireReels = functions.pubsub
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
    const batches = [];
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
    if (count % 500 !== 0)
        batches.push(batch);
    await Promise.all(batches.map(b => b.commit()));
    console.log(`Expired ${count} reels`);
});
//# sourceMappingURL=expireReels.js.map
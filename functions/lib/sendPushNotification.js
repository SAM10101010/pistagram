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
exports.sendPushNotification = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
if (!admin.apps.length)
    admin.initializeApp();
const db = admin.firestore();
const PUSH_TYPES = ['follow', 'follow_request', 'like', 'comment', 'message'];
exports.sendPushNotification = functions.firestore
    .document('notifications/{notifId}')
    .onCreate(async (snap) => {
    const data = snap.data();
    if (!data)
        return;
    const { toUid, fromUid, type, message, postId, reelId } = data;
    // Only send push for relevant notification types
    if (!PUSH_TYPES.includes(type))
        return;
    // Get recipient's user document for FCM tokens + privacy settings
    const recipientDoc = await db.collection('users').doc(toUid).get();
    if (!recipientDoc.exists)
        return;
    const recipient = recipientDoc.data();
    const tokens = recipient.fcmTokens || [];
    if (tokens.length === 0)
        return;
    // Respect privacy / mute settings
    const privacy = recipient.privacySettings || {};
    if (type === 'like' && privacy.muteLikes === true)
        return;
    if (type === 'comment' && privacy.muteComments === true)
        return;
    // Get sender's display info
    let senderName = 'Someone';
    if (fromUid) {
        const senderDoc = await db.collection('users').doc(fromUid).get();
        if (senderDoc.exists) {
            const senderData = senderDoc.data();
            senderName = senderData.displayName || senderData.username || 'Someone';
        }
    }
    // Build notification title and body
    let title = 'Pistagram';
    let body = message || '';
    switch (type) {
        case 'follow':
            title = 'New Follower';
            body = `${senderName} started following you.`;
            break;
        case 'follow_request':
            title = 'Follow Request';
            body = `${senderName} wants to follow you.`;
            break;
        case 'like':
            title = 'New Like';
            body = `${senderName} liked your ${postId ? 'post' : 'reel'}.`;
            break;
        case 'comment':
            title = 'New Comment';
            body = `${senderName} commented: ${message}`;
            break;
        case 'message':
            title = 'New Message';
            body = `${senderName} sent you a message.`;
            break;
    }
    // Build FCM payload
    const payload = {
        tokens,
        notification: { title, body },
        data: {
            type: type || '',
            fromUid: fromUid || '',
            postId: postId || '',
            reelId: reelId || '',
        },
        android: {
            notification: {
                channelId: 'pistagram_notifications',
                icon: '@mipmap/ic_launcher',
                priority: 'high',
            },
        },
        apns: {
            payload: {
                aps: { badge: 1, sound: 'default' },
            },
        },
    };
    // Send to all devices
    const response = await admin.messaging().sendEachForMulticast(payload);
    // Clean up stale/invalid tokens
    if (response.failureCount > 0) {
        const staleTokens = [];
        response.responses.forEach((resp, idx) => {
            var _a;
            if (!resp.success) {
                const code = (_a = resp.error) === null || _a === void 0 ? void 0 : _a.code;
                if (code === 'messaging/invalid-registration-token' ||
                    code === 'messaging/registration-token-not-registered') {
                    staleTokens.push(tokens[idx]);
                }
            }
        });
        if (staleTokens.length > 0) {
            await db.collection('users').doc(toUid).update({
                fcmTokens: admin.firestore.FieldValue.arrayRemove(staleTokens),
            });
            console.log(`Removed ${staleTokens.length} stale tokens for user ${toUid}`);
        }
    }
    console.log(`Push sent to ${toUid}: ${response.successCount} success, ${response.failureCount} failed`);
});
//# sourceMappingURL=sendPushNotification.js.map
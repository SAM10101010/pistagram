import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const PUSH_TYPES = ['follow', 'follow_request', 'like', 'comment', 'message'];

export const sendPushNotification = functions.firestore
  .document('notifications/{notifId}')
  .onCreate(async (snap: functions.firestore.QueryDocumentSnapshot) => {
    const data = snap.data();
    if (!data) return;

    const { toUid, fromUid, type, message, postId, reelId } = data;

    // Only send push for relevant notification types
    if (!PUSH_TYPES.includes(type)) return;

    // Get recipient's user document for FCM tokens + privacy settings
    const recipientDoc = await db.collection('users').doc(toUid).get();
    if (!recipientDoc.exists) return;

    const recipient = recipientDoc.data()!;
    const tokens: string[] = recipient.fcmTokens || [];
    if (tokens.length === 0) return;

    // Respect privacy / mute settings
    const privacy = recipient.privacySettings || {};
    if (type === 'like' && privacy.muteLikes === true) return;
    if (type === 'comment' && privacy.muteComments === true) return;

    // Get sender's display info
    let senderName = 'Someone';
    if (fromUid) {
      const senderDoc = await db.collection('users').doc(fromUid).get();
      if (senderDoc.exists) {
        const senderData = senderDoc.data()!;
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
    const payload: admin.messaging.MulticastMessage = {
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
          priority: 'high' as const,
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
      const staleTokens: string[] = [];
      response.responses.forEach((resp: admin.messaging.SendResponse, idx: number) => {
        if (!resp.success) {
          const code = resp.error?.code;
          if (
            code === 'messaging/invalid-registration-token' ||
            code === 'messaging/registration-token-not-registered'
          ) {
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

    console.log(
      `Push sent to ${toUid}: ${response.successCount} success, ${response.failureCount} failed`
    );
  });

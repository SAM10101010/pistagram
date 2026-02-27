import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

if (!admin.apps.length) admin.initializeApp();

export const checkSecretReelLimit = functions.firestore
  .document('reels/{reelId}')
  .onUpdate(async (change) => {
    const after = change.after.data();
    const before = change.before.data();

    // Only check if views changed and reel is limited
    if (!after.isLimited || !after.isActive) return;
    if (after.viewsCount === before.viewsCount) return;

    if (after.viewsCount >= after.maxViews) {
      await change.after.ref.update({ isActive: false });
      console.log(`Secret reel ${change.after.id} reached view limit (${after.viewsCount}/${after.maxViews})`);
    }
  });

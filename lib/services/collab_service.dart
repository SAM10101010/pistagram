import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/notification_model.dart';
import 'firestore_service.dart';
import 'messaging_service.dart';

class CollabService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final MessagingService _messagingService = MessagingService();
  final _uuid = const Uuid();

  /// Send a collab invite to a tagged user.
  /// Creates a collabInvites doc + notification + DM.
  Future<void> sendCollabInvite({
    required String fromUid,
    required String toUid,
    required String contentType, // 'reel', 'post', 'story'
    required String contentId,
  }) async {
    final inviteId = _uuid.v4();

    // Create the collab invite doc
    await _db.collection('collabInvites').doc(inviteId).set({
      'id': inviteId,
      'fromUid': fromUid,
      'toUid': toUid,
      'contentType': contentType,
      'contentId': contentId,
      'status': 'pending', // pending, accepted, rejected
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Send notification
    await _firestoreService.addNotification(
      NotificationModel(
        id: inviteId,
        toUid: toUid,
        fromUid: fromUid,
        type: 'collab_invite',
        reelId: contentType == 'reel' ? contentId : '',
        postId: contentType == 'post' ? contentId : '',
        message: 'invited you to collaborate on a $contentType',
      ),
    );

    // Send a DM with the collab invite
    try {
      final chat = await _messagingService.getOrCreateChat(fromUid, toUid);
      await _messagingService.sendMessage(
        chatId: chat.chatId,
        senderUid: fromUid,
        text: 'I tagged you in my $contentType! Accept the collab invite to share it on your profile too.',
      );
    } catch (_) {
      // DM may fail if blocked — that's ok, notification still sent
    }
  }

  /// Accept a collab invite — adds the user to the content's collaborators list.
  Future<void> acceptInvite(String inviteId) async {
    final doc = await _db.collection('collabInvites').doc(inviteId).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final contentType = data['contentType'] as String;
    final contentId = data['contentId'] as String;
    final toUid = data['toUid'] as String;
    final fromUid = data['fromUid'] as String;

    // Update invite status
    await _db.collection('collabInvites').doc(inviteId).update({
      'status': 'accepted',
    });

    // Add user to the content's collaborators list
    final collection = contentType == 'reel' ? 'reels'
        : contentType == 'post' ? 'posts'
        : 'stories';
    final idField = contentType == 'reel' ? 'reelId'
        : contentType == 'post' ? 'postId'
        : 'storyId';

    final contentSnap = await _db.collection(collection)
        .where(idField, isEqualTo: contentId)
        .limit(1)
        .get();

    if (contentSnap.docs.isNotEmpty) {
      await contentSnap.docs.first.reference.update({
        'collaborators': FieldValue.arrayUnion([toUid]),
      });
    }

    // Notify the original creator
    await _firestoreService.addNotification(
      NotificationModel(
        id: _uuid.v4(),
        toUid: fromUid,
        fromUid: toUid,
        type: 'collab_accepted',
        reelId: contentType == 'reel' ? contentId : '',
        postId: contentType == 'post' ? contentId : '',
        message: 'accepted your collab invite',
      ),
    );
  }

  /// Reject a collab invite.
  Future<void> rejectInvite(String inviteId) async {
    final doc = await _db.collection('collabInvites').doc(inviteId).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final fromUid = data['fromUid'] as String;
    final toUid = data['toUid'] as String;

    await _db.collection('collabInvites').doc(inviteId).update({
      'status': 'rejected',
    });

    // Notify the original creator
    await _firestoreService.addNotification(
      NotificationModel(
        id: _uuid.v4(),
        toUid: fromUid,
        fromUid: toUid,
        type: 'collab_rejected',
        message: 'declined your collab invite',
      ),
    );
  }

  /// Get pending collab invites for a user.
  Future<List<Map<String, dynamic>>> getPendingInvites(String uid) async {
    final snap = await _db.collection('collabInvites')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  /// Get the status of a specific collab invite by notification/invite ID.
  Future<String> getInviteStatus(String inviteId) async {
    final doc = await _db.collection('collabInvites').doc(inviteId).get();
    if (!doc.exists) return 'unknown';
    return doc.data()?['status'] ?? 'unknown';
  }
}

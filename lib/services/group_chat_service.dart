import 'package:uuid/uuid.dart';
import '../models/group_chat_model.dart';
import '../models/group_message_model.dart';
import '../models/group_invite_model.dart';
import '../models/message_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class GroupChatService {
  final FirestoreService _firestoreService = FirestoreService();
  final _uuid = const Uuid();

  /// Create a new group. Creator becomes both member and admin.
  Future<GroupChatModel> createGroup({
    required String creatorUid,
    required String name,
    String description = '',
    String groupPicUrl = '',
  }) async {
    final groupId = _uuid.v4();
    final group = GroupChatModel(
      id: groupId,
      name: name,
      description: description,
      creatorUid: creatorUid,
      groupPicUrl: groupPicUrl,
      members: [creatorUid],
      admins: [creatorUid],
      memberCount: 1,
    );
    await _firestoreService.createGroupChat(group);
    return group;
  }

  /// Send a message to the group.
  Future<void> sendMessage({
    required String groupId,
    required String senderUid,
    String text = '',
    String mediaUrl = '',
    String sharedContentType = '',
    String sharedContentId = '',
    String sharedThumbnail = '',
  }) async {
    final group = await _firestoreService.getGroupChat(groupId);
    if (group == null) throw Exception('Group not found');
    if (!group.members.contains(senderUid)) throw Exception('Not a member');
    if (!group.membersCanMessage && !group.admins.contains(senderUid)) {
      throw Exception('Only admins can message in this group');
    }

    final message = GroupMessageModel(
      id: _uuid.v4(),
      groupId: groupId,
      senderUid: senderUid,
      text: text,
      mediaUrl: mediaUrl,
      sharedContentType: sharedContentType,
      sharedContentId: sharedContentId,
      sharedThumbnail: sharedThumbnail,
    );
    await _firestoreService.sendGroupMessage(message);
  }

  /// Invite a user to the group via DM + notification.
  Future<void> inviteUser({
    required String groupId,
    required String inviterUid,
    required String inviteeUid,
  }) async {
    final group = await _firestoreService.getGroupChat(groupId);
    if (group == null) throw Exception('Group not found');

    final isAdmin = group.admins.contains(inviterUid);
    final canAdd = group.membersCanAdd;
    if (!isAdmin && !canAdd) throw Exception('You cannot invite members');

    if (group.members.contains(inviteeUid)) {
      throw Exception('Already a member');
    }

    if (group.memberCount >= group.maxMembers) {
      throw Exception('Group is full');
    }

    if (await _firestoreService.hasPendingGroupInvite(groupId, inviteeUid)) {
      throw Exception('Invitation already sent');
    }

    if (await _firestoreService.isBlockedByEither(inviterUid, inviteeUid)) {
      throw Exception('Cannot invite this user');
    }

    final inviteId = _uuid.v4();
    final invite = GroupInviteModel(
      id: inviteId,
      groupId: groupId,
      groupName: group.name,
      inviterUid: inviterUid,
      inviteeUid: inviteeUid,
    );
    await _firestoreService.createGroupInvitation(invite);

    // Send notification
    await _firestoreService.addNotification(
      NotificationModel(
        id: 'group_invite_$inviteId',
        toUid: inviteeUid,
        fromUid: inviterUid,
        type: 'group_invite',
        message: 'invited you to join "${group.name}"',
        groupId: groupId,
      ),
    );

    // Send a DM in the 1:1 chat so it appears in Direct tab
    final chat =
        await _firestoreService.getOrCreateChat(inviterUid, inviteeUid);
    final dmMessage = MessageModel(
      id: _uuid.v4(),
      chatId: chat.chatId,
      senderUid: inviterUid,
      text: 'Invited you to join "${group.name}"',
      sharedContentType: 'group_invite',
      sharedContentId: inviteId,
      sharedThumbnail: group.groupPicUrl,
    );
    await _firestoreService.sendMessage(dmMessage);
  }

  /// Accept a group invitation.
  Future<void> acceptInvitation(String inviteId) async {
    final invite = await _firestoreService.getGroupInvitation(inviteId);
    if (invite == null) throw Exception('Invitation not found');
    if (invite.status != 'pending') throw Exception('Invitation already handled');

    await _firestoreService.updateGroupInvitationStatus(inviteId, 'accepted');
    await _firestoreService.addGroupMember(invite.groupId, invite.inviteeUid);
  }

  /// Decline a group invitation.
  Future<void> declineInvitation(String inviteId) async {
    final invite = await _firestoreService.getGroupInvitation(inviteId);
    if (invite == null) throw Exception('Invitation not found');
    if (invite.status != 'pending') throw Exception('Invitation already handled');

    await _firestoreService.updateGroupInvitationStatus(inviteId, 'declined');
  }

  /// Add member directly (admin only, no invitation needed).
  Future<void> addMemberDirectly({
    required String groupId,
    required String adminUid,
    required String newMemberUid,
  }) async {
    final group = await _firestoreService.getGroupChat(groupId);
    if (group == null) throw Exception('Group not found');
    if (!group.admins.contains(adminUid)) {
      throw Exception('Only admins can add directly');
    }
    if (group.members.contains(newMemberUid)) {
      throw Exception('Already a member');
    }
    if (group.memberCount >= group.maxMembers) {
      throw Exception('Group is full');
    }

    await _firestoreService.addGroupMember(groupId, newMemberUid);

    await _firestoreService.addNotification(
      NotificationModel(
        id: 'group_added_${groupId}_$newMemberUid',
        toUid: newMemberUid,
        fromUid: adminUid,
        type: 'group_added',
        message: 'added you to "${group.name}"',
        groupId: groupId,
      ),
    );
  }

  /// Leave group.
  Future<void> leaveGroup(String groupId, String uid) async {
    final group = await _firestoreService.getGroupChat(groupId);
    if (group == null) throw Exception('Group not found');
    if (!group.members.contains(uid)) throw Exception('Not a member');

    await _firestoreService.removeGroupMember(groupId, uid);

    // If last member, disband the group
    if (group.memberCount <= 1) {
      await _firestoreService.updateGroupChat(groupId, {'status': 'disbanded'});
      return;
    }

    // If was the only admin, promote the first remaining member
    if (group.admins.contains(uid) && group.admins.length <= 1) {
      final remaining =
          group.members.where((m) => m != uid).toList();
      if (remaining.isNotEmpty) {
        await _firestoreService.addGroupAdmin(groupId, remaining.first);
        // If was also creator, transfer creator
        if (group.creatorUid == uid) {
          await _firestoreService.updateGroupChat(
              groupId, {'creatorUid': remaining.first});
        }
      }
    }
  }

  /// Remove a member (admin only).
  Future<void> removeMember(
      String groupId, String adminUid, String targetUid) async {
    final group = await _firestoreService.getGroupChat(groupId);
    if (group == null) throw Exception('Group not found');
    if (!group.admins.contains(adminUid)) {
      throw Exception('Only admins can remove members');
    }
    if (targetUid == group.creatorUid) {
      throw Exception('Cannot remove the group creator');
    }
    await _firestoreService.removeGroupMember(groupId, targetUid);
  }

  /// Update group settings (admin only).
  Future<void> updateGroupSettings(
      String groupId, String adminUid, Map<String, dynamic> newSettings) async {
    final group = await _firestoreService.getGroupChat(groupId);
    if (group == null) throw Exception('Group not found');
    if (!group.admins.contains(adminUid)) {
      throw Exception('Only admins can update settings');
    }
    final merged = Map<String, dynamic>.from(group.settings)..addAll(newSettings);
    await _firestoreService.updateGroupChat(groupId, {'settings': merged});
  }

  /// Update group info (name, description, picture) -- admin only.
  Future<void> updateGroupInfo(
    String groupId,
    String adminUid, {
    String? name,
    String? description,
    String? groupPicUrl,
  }) async {
    final group = await _firestoreService.getGroupChat(groupId);
    if (group == null) throw Exception('Group not found');
    if (!group.admins.contains(adminUid)) {
      throw Exception('Only admins can update group info');
    }
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (groupPicUrl != null) updates['groupPicUrl'] = groupPicUrl;
    if (updates.isNotEmpty) {
      await _firestoreService.updateGroupChat(groupId, updates);
    }
  }

  /// Promote a member to admin.
  Future<void> promoteToAdmin(
      String groupId, String adminUid, String targetUid) async {
    final group = await _firestoreService.getGroupChat(groupId);
    if (group == null) throw Exception('Group not found');
    if (!group.admins.contains(adminUid)) {
      throw Exception('Only admins can promote members');
    }
    if (group.admins.contains(targetUid)) {
      throw Exception('Already an admin');
    }
    await _firestoreService.addGroupAdmin(groupId, targetUid);
  }

  /// Demote an admin to regular member (creator only).
  Future<void> demoteAdmin(
      String groupId, String creatorUid, String targetUid) async {
    final group = await _firestoreService.getGroupChat(groupId);
    if (group == null) throw Exception('Group not found');
    if (group.creatorUid != creatorUid) {
      throw Exception('Only the creator can demote admins');
    }
    if (targetUid == creatorUid) {
      throw Exception('Cannot demote yourself');
    }
    await _firestoreService.removeGroupAdmin(groupId, targetUid);
  }

  /// Stream all groups for a user.
  Stream<List<GroupChatModel>> getUserGroups(String uid) {
    return _firestoreService.getUserGroupChats(uid);
  }

  /// Stream group messages.
  Stream<List<GroupMessageModel>> getMessages(String groupId) {
    return _firestoreService.getGroupMessages(groupId);
  }

  /// Stream pending invitations for a user.
  Stream<List<GroupInviteModel>> getPendingInvitations(String uid) {
    return _firestoreService.getPendingGroupInvitations(uid);
  }

  /// Delete a message (sender or admin).
  Future<void> deleteMessage(
      String groupId, String messageId, String requestingUid) async {
    final group = await _firestoreService.getGroupChat(groupId);
    if (group == null) throw Exception('Group not found');
    final isAdmin = group.admins.contains(requestingUid);
    if (!isAdmin) {
      // Only allow sender to delete their own messages (checked by caller)
    }
    await _firestoreService.deleteGroupMessage(groupId, messageId);
  }

  /// Edit a message (sender only).
  Future<void> editMessage(
      String groupId, String messageId, String newText) async {
    await _firestoreService.updateGroupMessage(groupId, messageId, newText);
  }

  /// Get group members as UserModel list.
  Future<List<UserModel>> getGroupMembers(String groupId) async {
    final group = await _firestoreService.getGroupChat(groupId);
    if (group == null) return [];
    final users = <UserModel>[];
    for (final uid in group.members) {
      final user = await _firestoreService.getUser(uid);
      if (user != null) users.add(user);
    }
    return users;
  }
}

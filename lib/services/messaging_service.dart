import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class MessagingService {
  final FirestoreService _firestoreService = FirestoreService();
  final _uuid = const Uuid();

  Future<ChatModel> getOrCreateChat(String currentUid, String otherUid) async {
    // Enforce privacy: check blocks
    if (await _firestoreService.isBlockedByEither(currentUid, otherUid)) {
      throw Exception('Cannot message this user');
    }

    // Check messaging privacy settings
    final otherUser = await _firestoreService.getUser(otherUid);
    if (otherUser != null) {
      final messagesFrom = otherUser.privacySettings['messagesFrom'] ?? 'everyone';
      if (messagesFrom == 'followers') {
        final isFollower = await _firestoreService.getFollow(currentUid, otherUid);
        if (isFollower == null || isFollower.status != 'accepted') {
          throw Exception('This user only accepts messages from followers');
        }
      } else if (messagesFrom == 'none') {
        throw Exception('This user has disabled messages');
      }
    }

    return await _firestoreService.getOrCreateChat(currentUid, otherUid);
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderUid,
    String text = '',
    String mediaUrl = '',
  }) async {
    final message = MessageModel(
      id: _uuid.v4(),
      chatId: chatId,
      senderUid: senderUid,
      text: text,
      mediaUrl: mediaUrl,
    );
    await _firestoreService.sendMessage(message);

    // Create notification for the receiver (use stable ID per chat to avoid spam)
    final chat = await _firestoreService.getChat(chatId);
    if (chat != null) {
      final receiverUid = chat.participants.firstWhere(
        (p) => p != senderUid,
        orElse: () => '',
      );
      if (receiverUid.isNotEmpty) {
        await _firestoreService.addNotification(NotificationModel(
          id: 'msg_${chatId}_$senderUid',
          toUid: receiverUid,
          fromUid: senderUid,
          type: 'message',
          message: 'sent you a message',
        ));
      }
    }
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestoreService.getMessages(chatId);
  }

  Stream<List<ChatModel>> getUserChats(String uid) {
    return _firestoreService.getUserChats(uid);
  }

  Future<UserModel?> getChatPartner(ChatModel chat, String currentUid) async {
    final otherUid = chat.participants.firstWhere(
      (p) => p != currentUid,
      orElse: () => '',
    );
    if (otherUid.isEmpty) return null;
    return await _firestoreService.getUser(otherUid);
  }
}

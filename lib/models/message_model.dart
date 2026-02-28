import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String chatId;
  final String senderUid;
  final String text;
  final String mediaUrl;
  final bool isEdited;
  final DateTime? readAt;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderUid,
    this.text = '',
    this.mediaUrl = '',
    this.isEdited = false,
    this.readAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      chatId: map['chatId'] ?? '',
      senderUid: map['senderUid'] ?? '',
      text: map['text'] ?? '',
      mediaUrl: map['mediaUrl'] ?? '',
      isEdited: map['isEdited'] ?? false,
      readAt: (map['readAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderUid': senderUid,
      'text': text,
      'mediaUrl': mediaUrl,
      'isEdited': isEdited,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class ChatModel {
  final String chatId;
  final List<String> participants;
  final String lastMessage;
  final String lastSenderUid;
  final DateTime lastMessageAt;
  final DateTime createdAt;

  ChatModel({
    required this.chatId,
    required this.participants,
    this.lastMessage = '',
    this.lastSenderUid = '',
    DateTime? lastMessageAt,
    DateTime? createdAt,
  }) : lastMessageAt = lastMessageAt ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now();

  factory ChatModel.fromMap(Map<String, dynamic> map) {
    return ChatModel(
      chatId: map['chatId'] ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastSenderUid: map['lastSenderUid'] ?? '',
      lastMessageAt:
          (map['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastSenderUid': lastSenderUid,
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

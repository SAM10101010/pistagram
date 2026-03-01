import 'package:cloud_firestore/cloud_firestore.dart';

class GroupMessageModel {
  final String id;
  final String groupId;
  final String senderUid;
  final String text;
  final String mediaUrl;
  final String sharedContentType;
  final String sharedContentId;
  final String sharedThumbnail;
  final bool isEdited;
  final DateTime createdAt;

  GroupMessageModel({
    required this.id,
    required this.groupId,
    required this.senderUid,
    this.text = '',
    this.mediaUrl = '',
    this.sharedContentType = '',
    this.sharedContentId = '',
    this.sharedThumbnail = '',
    this.isEdited = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory GroupMessageModel.fromMap(Map<String, dynamic> map) {
    return GroupMessageModel(
      id: map['id'] ?? '',
      groupId: map['groupId'] ?? '',
      senderUid: map['senderUid'] ?? '',
      text: map['text'] ?? '',
      mediaUrl: map['mediaUrl'] ?? '',
      sharedContentType: map['sharedContentType'] ?? '',
      sharedContentId: map['sharedContentId'] ?? '',
      sharedThumbnail: map['sharedThumbnail'] ?? '',
      isEdited: map['isEdited'] ?? false,
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'senderUid': senderUid,
      'text': text,
      'mediaUrl': mediaUrl,
      'sharedContentType': sharedContentType,
      'sharedContentId': sharedContentId,
      'sharedThumbnail': sharedThumbnail,
      'isEdited': isEdited,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

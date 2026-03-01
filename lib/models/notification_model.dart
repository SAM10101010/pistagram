import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String toUid;
  final String fromUid;
  final String
  type; // follow, follow_request, like, comment, comment_reply, comment_like, message, points, reward, story_reaction
  final String reelId;
  final String postId;
  final String commentId;
  final String groupId;
  final String message;
  final bool read;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.toUid,
    required this.fromUid,
    required this.type,
    this.reelId = '',
    this.postId = '',
    this.commentId = '',
    this.groupId = '',
    this.message = '',
    this.read = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      toUid: map['toUid'] ?? '',
      fromUid: map['fromUid'] ?? '',
      type: map['type'] ?? '',
      reelId: map['reelId'] ?? '',
      postId: map['postId'] ?? '',
      commentId: map['commentId'] ?? '',
      groupId: map['groupId'] ?? '',
      message: map['message'] ?? '',
      read: map['read'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'toUid': toUid,
      'fromUid': fromUid,
      'type': type,
      'reelId': reelId,
      'postId': postId,
      'commentId': commentId,
      'groupId': groupId,
      'message': message,
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

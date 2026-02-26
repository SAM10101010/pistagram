import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String toUid;
  final String fromUid;
  final String type; // follow, like, comment, points, reward
  final String reelId;
  final String message;
  final bool read;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.toUid,
    required this.fromUid,
    required this.type,
    this.reelId = '',
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
      'message': message,
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

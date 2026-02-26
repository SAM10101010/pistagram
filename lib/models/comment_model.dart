import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String reelId;
  final String uid;
  final String text;
  final String parentId; // for replies
  final int likesCount;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.reelId,
    required this.uid,
    required this.text,
    this.parentId = '',
    this.likesCount = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    return CommentModel(
      id: map['id'] ?? '',
      reelId: map['reelId'] ?? '',
      uid: map['uid'] ?? '',
      text: map['text'] ?? '',
      parentId: map['parentId'] ?? '',
      likesCount: map['likesCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reelId': reelId,
      'uid': uid,
      'text': text,
      'parentId': parentId,
      'likesCount': likesCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

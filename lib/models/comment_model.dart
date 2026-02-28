import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String reelId;
  final String uid;
  final String text;
  final String parentId; // for replies
  final int likesCount;
  final List<String> likedByUids;
  final int repliesCount;
  final DateTime createdAt;
  // Quality ranking (Feature 4)
  final double commentScore;
  final int upvotes;
  final int downvotes;
  final int characterCount;

  CommentModel({
    required this.id,
    required this.reelId,
    required this.uid,
    required this.text,
    this.parentId = '',
    this.likesCount = 0,
    this.likedByUids = const [],
    this.repliesCount = 0,
    DateTime? createdAt,
    this.commentScore = 0.0,
    this.upvotes = 0,
    this.downvotes = 0,
    int? characterCount,
  }) : createdAt = createdAt ?? DateTime.now(),
       characterCount = characterCount ?? text.length;

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    return CommentModel(
      id: map['id'] ?? '',
      reelId: map['reelId'] ?? '',
      uid: map['uid'] ?? '',
      text: map['text'] ?? '',
      parentId: map['parentId'] ?? '',
      likesCount: map['likesCount'] ?? 0,
      likedByUids: List<String>.from(map['likedByUids'] ?? []),
      repliesCount: map['repliesCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      commentScore: (map['commentScore'] ?? 0.0).toDouble(),
      upvotes: map['upvotes'] ?? 0,
      downvotes: map['downvotes'] ?? 0,
      characterCount: map['characterCount'] ?? (map['text'] ?? '').length,
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
      'likedByUids': likedByUids,
      'repliesCount': repliesCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'commentScore': commentScore,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'characterCount': characterCount,
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class StoryReactionModel {
  final String id;
  final String storyId;
  final String userId;
  final String reactionType; // emoji string
  final DateTime createdAt;

  StoryReactionModel({
    required this.id,
    required this.storyId,
    required this.userId,
    required this.reactionType,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory StoryReactionModel.fromMap(Map<String, dynamic> map) {
    return StoryReactionModel(
      id: map['id'] ?? '',
      storyId: map['storyId'] ?? '',
      userId: map['userId'] ?? '',
      reactionType: map['reactionType'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storyId': storyId,
      'userId': userId,
      'reactionType': reactionType,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

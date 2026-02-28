import 'package:cloud_firestore/cloud_firestore.dart';

class ReflectionModel {
  final String reflectionId;
  final String userId;
  final String prompt;
  final String response;
  final List<String> reelIdsWatched;
  final DateTime createdAt;

  ReflectionModel({
    required this.reflectionId,
    required this.userId,
    required this.prompt,
    this.response = '',
    List<String>? reelIdsWatched,
    DateTime? createdAt,
  }) : reelIdsWatched = reelIdsWatched ?? [],
       createdAt = createdAt ?? DateTime.now();

  factory ReflectionModel.fromMap(Map<String, dynamic> map) {
    return ReflectionModel(
      reflectionId: map['reflectionId'] ?? '',
      userId: map['userId'] ?? '',
      prompt: map['prompt'] ?? '',
      response: map['response'] ?? '',
      reelIdsWatched: List<String>.from(map['reelIdsWatched'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reflectionId': reflectionId,
      'userId': userId,
      'prompt': prompt,
      'response': response,
      'reelIdsWatched': reelIdsWatched,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

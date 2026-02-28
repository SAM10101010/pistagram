import 'package:cloud_firestore/cloud_firestore.dart';

class UserActivityModel {
  final String id; // {userId}_{dayOfWeek}_{hour}
  final String userId;
  final String dayOfWeek; // monday-sunday
  final int hour; // 0-23
  final int interactionCount;
  final DateTime lastUpdated;

  UserActivityModel({
    required this.id,
    required this.userId,
    required this.dayOfWeek,
    required this.hour,
    this.interactionCount = 0,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  factory UserActivityModel.fromMap(Map<String, dynamic> map) {
    return UserActivityModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      dayOfWeek: map['dayOfWeek'] ?? '',
      hour: map['hour'] ?? 0,
      interactionCount: map['interactionCount'] ?? 0,
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'dayOfWeek': dayOfWeek,
      'hour': hour,
      'interactionCount': interactionCount,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}

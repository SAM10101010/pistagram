import 'package:cloud_firestore/cloud_firestore.dart';

class ChallengeModel {
  final String id;
  final String title;
  final String description;
  final String type; // weekly, daily, special
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final int participantCount;
  final String rewardDescription;
  final int rewardPoints;
  final DateTime createdAt;

  ChallengeModel({
    required this.id,
    required this.title,
    this.description = '',
    this.type = 'weekly',
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.participantCount = 0,
    this.rewardDescription = '',
    this.rewardPoints = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ChallengeModel.fromMap(Map<String, dynamic> map) {
    return ChallengeModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? 'weekly',
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
      participantCount: map['participantCount'] ?? 0,
      rewardDescription: map['rewardDescription'] ?? '',
      rewardPoints: map['rewardPoints'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      'participantCount': participantCount,
      'rewardDescription': rewardDescription,
      'rewardPoints': rewardPoints,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

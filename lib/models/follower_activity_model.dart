import 'package:cloud_firestore/cloud_firestore.dart';

class FollowerActivityModel {
  final String id; // {creatorId}_{dayOfWeek}_{hour}
  final String creatorId;
  final String dayOfWeek;
  final int hour;
  final int activeFollowerCount;
  final double avgEngagementRate;
  final DateTime lastCalculated;

  FollowerActivityModel({
    required this.id,
    required this.creatorId,
    required this.dayOfWeek,
    required this.hour,
    this.activeFollowerCount = 0,
    this.avgEngagementRate = 0.0,
    DateTime? lastCalculated,
  }) : lastCalculated = lastCalculated ?? DateTime.now();

  factory FollowerActivityModel.fromMap(Map<String, dynamic> map) {
    return FollowerActivityModel(
      id: map['id'] ?? '',
      creatorId: map['creatorId'] ?? '',
      dayOfWeek: map['dayOfWeek'] ?? '',
      hour: map['hour'] ?? 0,
      activeFollowerCount: map['activeFollowerCount'] ?? 0,
      avgEngagementRate: (map['avgEngagementRate'] ?? 0.0).toDouble(),
      lastCalculated: (map['lastCalculated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'creatorId': creatorId,
      'dayOfWeek': dayOfWeek,
      'hour': hour,
      'activeFollowerCount': activeFollowerCount,
      'avgEngagementRate': avgEngagementRate,
      'lastCalculated': Timestamp.fromDate(lastCalculated),
    };
  }
}

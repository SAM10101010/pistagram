import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklySummaryModel {
  final String id; // {userId}_{weekStartDate}
  final String userId;
  final DateTime weekStart;
  final DateTime weekEnd;
  final int followersStart;
  final int followersEnd;
  final int followersGained;
  final int followersLost;
  final int totalViews;
  final int totalLikes;
  final int totalComments;
  final double avgCompletionRate;
  final String engagementTrend; // up, down, stable
  final String topReelId;
  final DateTime createdAt;

  WeeklySummaryModel({
    required this.id,
    required this.userId,
    required this.weekStart,
    required this.weekEnd,
    this.followersStart = 0,
    this.followersEnd = 0,
    this.followersGained = 0,
    this.followersLost = 0,
    this.totalViews = 0,
    this.totalLikes = 0,
    this.totalComments = 0,
    this.avgCompletionRate = 0.0,
    this.engagementTrend = 'stable',
    this.topReelId = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get followerChange => followersGained - followersLost;

  factory WeeklySummaryModel.fromMap(Map<String, dynamic> map) {
    return WeeklySummaryModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      weekStart: (map['weekStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      weekEnd: (map['weekEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
      followersStart: map['followersStart'] ?? 0,
      followersEnd: map['followersEnd'] ?? 0,
      followersGained: map['followersGained'] ?? 0,
      followersLost: map['followersLost'] ?? 0,
      totalViews: map['totalViews'] ?? 0,
      totalLikes: map['totalLikes'] ?? 0,
      totalComments: map['totalComments'] ?? 0,
      avgCompletionRate: (map['avgCompletionRate'] ?? 0.0).toDouble(),
      engagementTrend: map['engagementTrend'] ?? 'stable',
      topReelId: map['topReelId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'weekStart': Timestamp.fromDate(weekStart),
      'weekEnd': Timestamp.fromDate(weekEnd),
      'followersStart': followersStart,
      'followersEnd': followersEnd,
      'followersGained': followersGained,
      'followersLost': followersLost,
      'totalViews': totalViews,
      'totalLikes': totalLikes,
      'totalComments': totalComments,
      'avgCompletionRate': avgCompletionRate,
      'engagementTrend': engagementTrend,
      'topReelId': topReelId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

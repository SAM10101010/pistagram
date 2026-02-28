import 'package:cloud_firestore/cloud_firestore.dart';

class CloseFriendAnalyticsModel {
  final String id; // {ownerId}_{supporterId}
  final String ownerId;
  final String supporterId;
  final int storyViews;
  final int storyReplies;
  final int reelLikes;
  final int reelComments;
  final double avgStoryWatchPercent;
  final double interactionScore;
  final DateTime lastUpdated;

  CloseFriendAnalyticsModel({
    required this.id,
    required this.ownerId,
    required this.supporterId,
    this.storyViews = 0,
    this.storyReplies = 0,
    this.reelLikes = 0,
    this.reelComments = 0,
    this.avgStoryWatchPercent = 0.0,
    this.interactionScore = 0.0,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  factory CloseFriendAnalyticsModel.fromMap(Map<String, dynamic> map) {
    return CloseFriendAnalyticsModel(
      id: map['id'] ?? '',
      ownerId: map['ownerId'] ?? '',
      supporterId: map['supporterId'] ?? '',
      storyViews: map['storyViews'] ?? 0,
      storyReplies: map['storyReplies'] ?? 0,
      reelLikes: map['reelLikes'] ?? 0,
      reelComments: map['reelComments'] ?? 0,
      avgStoryWatchPercent: (map['avgStoryWatchPercent'] ?? 0.0).toDouble(),
      interactionScore: (map['interactionScore'] ?? 0.0).toDouble(),
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'supporterId': supporterId,
      'storyViews': storyViews,
      'storyReplies': storyReplies,
      'reelLikes': reelLikes,
      'reelComments': reelComments,
      'avgStoryWatchPercent': avgStoryWatchPercent,
      'interactionScore': interactionScore,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}

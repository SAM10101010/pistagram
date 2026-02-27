import 'package:cloud_firestore/cloud_firestore.dart';

class CampaignModel {
  final String campaignId;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime startTime;
  final DateTime endTime;
  final String
  conditionType; // 'watch_count', 'streak_days', 'earn_points', 'like_count'
  final int conditionValue;
  final int rewardPoints;
  final String rewardType; // 'points', 'mystery_box', 'special_badge'
  final bool isActive;
  final DateTime createdAt;

  CampaignModel({
    required this.campaignId,
    required this.title,
    this.description = '',
    this.imageUrl = '',
    required this.startTime,
    required this.endTime,
    this.conditionType = 'watch_count',
    this.conditionValue = 20,
    this.rewardPoints = 50,
    this.rewardType = 'points',
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isLive =>
      isActive &&
      DateTime.now().isAfter(startTime) &&
      DateTime.now().isBefore(endTime);

  Duration get timeRemaining => endTime.difference(DateTime.now());

  factory CampaignModel.fromMap(Map<String, dynamic> map) {
    return CampaignModel(
      campaignId: map['campaignId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      startTime: (map['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (map['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      conditionType: map['conditionType'] ?? 'watch_count',
      conditionValue: map['conditionValue'] ?? 20,
      rewardPoints: map['rewardPoints'] ?? 50,
      rewardType: map['rewardType'] ?? 'points',
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'campaignId': campaignId,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'conditionType': conditionType,
      'conditionValue': conditionValue,
      'rewardPoints': rewardPoints,
      'rewardType': rewardType,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  CampaignModel copyWith({
    String? campaignId,
    String? title,
    String? description,
    String? imageUrl,
    DateTime? startTime,
    DateTime? endTime,
    String? conditionType,
    int? conditionValue,
    int? rewardPoints,
    String? rewardType,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return CampaignModel(
      campaignId: campaignId ?? this.campaignId,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      conditionType: conditionType ?? this.conditionType,
      conditionValue: conditionValue ?? this.conditionValue,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      rewardType: rewardType ?? this.rewardType,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class CampaignProgressModel {
  final String uid;
  final String campaignId;
  final int currentProgress;
  final bool completed;
  final bool rewardClaimed;
  final DateTime startedAt;
  final DateTime? completedAt;

  CampaignProgressModel({
    required this.uid,
    required this.campaignId,
    this.currentProgress = 0,
    this.completed = false,
    this.rewardClaimed = false,
    DateTime? startedAt,
    this.completedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  factory CampaignProgressModel.fromMap(Map<String, dynamic> map) {
    return CampaignProgressModel(
      uid: map['uid'] ?? '',
      campaignId: map['campaignId'] ?? '',
      currentProgress: map['currentProgress'] ?? 0,
      completed: map['completed'] ?? false,
      rewardClaimed: map['rewardClaimed'] ?? false,
      startedAt: (map['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'campaignId': campaignId,
      'currentProgress': currentProgress,
      'completed': completed,
      'rewardClaimed': rewardClaimed,
      'startedAt': Timestamp.fromDate(startedAt),
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
    };
  }

  CampaignProgressModel copyWith({
    String? uid,
    String? campaignId,
    int? currentProgress,
    bool? completed,
    bool? rewardClaimed,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return CampaignProgressModel(
      uid: uid ?? this.uid,
      campaignId: campaignId ?? this.campaignId,
      currentProgress: currentProgress ?? this.currentProgress,
      completed: completed ?? this.completed,
      rewardClaimed: rewardClaimed ?? this.rewardClaimed,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

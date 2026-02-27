import 'package:cloud_firestore/cloud_firestore.dart';

class SeriesModel {
  final String seriesId;
  final String creatorUid;
  final String title;
  final String description;
  final String coverImageUrl;
  final List<String> reelIds;
  final int totalReels;
  final int bonusPoints;
  final bool isActive;
  final DateTime createdAt;

  SeriesModel({
    required this.seriesId,
    required this.creatorUid,
    required this.title,
    this.description = '',
    this.coverImageUrl = '',
    List<String>? reelIds,
    this.totalReels = 0,
    this.bonusPoints = 25,
    this.isActive = true,
    DateTime? createdAt,
  }) : reelIds = reelIds ?? [],
       createdAt = createdAt ?? DateTime.now();

  factory SeriesModel.fromMap(Map<String, dynamic> map) {
    return SeriesModel(
      seriesId: map['seriesId'] ?? '',
      creatorUid: map['creatorUid'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      coverImageUrl: map['coverImageUrl'] ?? '',
      reelIds: List<String>.from(map['reelIds'] ?? []),
      totalReels: map['totalReels'] ?? 0,
      bonusPoints: map['bonusPoints'] ?? 25,
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'seriesId': seriesId,
      'creatorUid': creatorUid,
      'title': title,
      'description': description,
      'coverImageUrl': coverImageUrl,
      'reelIds': reelIds,
      'totalReels': totalReels,
      'bonusPoints': bonusPoints,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  SeriesModel copyWith({
    String? seriesId,
    String? creatorUid,
    String? title,
    String? description,
    String? coverImageUrl,
    List<String>? reelIds,
    int? totalReels,
    int? bonusPoints,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return SeriesModel(
      seriesId: seriesId ?? this.seriesId,
      creatorUid: creatorUid ?? this.creatorUid,
      title: title ?? this.title,
      description: description ?? this.description,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      reelIds: reelIds ?? this.reelIds,
      totalReels: totalReels ?? this.totalReels,
      bonusPoints: bonusPoints ?? this.bonusPoints,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SeriesProgressModel {
  final String uid;
  final String seriesId;
  final List<String> watchedReelIds;
  final bool completed;
  final DateTime? completedAt;
  final bool bonusAwarded;

  SeriesProgressModel({
    required this.uid,
    required this.seriesId,
    List<String>? watchedReelIds,
    this.completed = false,
    this.completedAt,
    this.bonusAwarded = false,
  }) : watchedReelIds = watchedReelIds ?? [];

  factory SeriesProgressModel.fromMap(Map<String, dynamic> map) {
    return SeriesProgressModel(
      uid: map['uid'] ?? '',
      seriesId: map['seriesId'] ?? '',
      watchedReelIds: List<String>.from(map['watchedReelIds'] ?? []),
      completed: map['completed'] ?? false,
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      bonusAwarded: map['bonusAwarded'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'seriesId': seriesId,
      'watchedReelIds': watchedReelIds,
      'completed': completed,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'bonusAwarded': bonusAwarded,
    };
  }

  double progress(int totalReels) =>
      totalReels > 0 ? watchedReelIds.length / totalReels : 0.0;

  SeriesProgressModel copyWith({
    String? uid,
    String? seriesId,
    List<String>? watchedReelIds,
    bool? completed,
    DateTime? completedAt,
    bool? bonusAwarded,
  }) {
    return SeriesProgressModel(
      uid: uid ?? this.uid,
      seriesId: seriesId ?? this.seriesId,
      watchedReelIds: watchedReelIds ?? this.watchedReelIds,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      bonusAwarded: bonusAwarded ?? this.bonusAwarded,
    );
  }
}

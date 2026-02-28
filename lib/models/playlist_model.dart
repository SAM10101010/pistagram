import 'package:cloud_firestore/cloud_firestore.dart';

class PlaylistModel {
  final String playlistId;
  final String ownerId;
  final String title;
  final String description;
  final String coverImageUrl;
  final List<String> reelIds;
  final int followerCount;
  final int totalViews;
  final double engagementScore;
  final String visibility; // public, private, followers
  final bool isCollaborative;
  final List<String> collaboratorIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlaylistModel({
    required this.playlistId,
    required this.ownerId,
    required this.title,
    this.description = '',
    this.coverImageUrl = '',
    List<String>? reelIds,
    this.followerCount = 0,
    this.totalViews = 0,
    this.engagementScore = 0.0,
    this.visibility = 'public',
    this.isCollaborative = false,
    List<String>? collaboratorIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : reelIds = reelIds ?? [],
       collaboratorIds = collaboratorIds ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  int get reelCount => reelIds.length;

  factory PlaylistModel.fromMap(Map<String, dynamic> map) {
    return PlaylistModel(
      playlistId: map['playlistId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      coverImageUrl: map['coverImageUrl'] ?? '',
      reelIds: List<String>.from(map['reelIds'] ?? []),
      followerCount: map['followerCount'] ?? 0,
      totalViews: map['totalViews'] ?? 0,
      engagementScore: (map['engagementScore'] ?? 0.0).toDouble(),
      visibility: map['visibility'] ?? 'public',
      isCollaborative: map['isCollaborative'] ?? false,
      collaboratorIds: List<String>.from(map['collaboratorIds'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'playlistId': playlistId,
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'coverImageUrl': coverImageUrl,
      'reelIds': reelIds,
      'followerCount': followerCount,
      'totalViews': totalViews,
      'engagementScore': engagementScore,
      'visibility': visibility,
      'isCollaborative': isCollaborative,
      'collaboratorIds': collaboratorIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  PlaylistModel copyWith({
    String? playlistId,
    String? ownerId,
    String? title,
    String? description,
    String? coverImageUrl,
    List<String>? reelIds,
    int? followerCount,
    int? totalViews,
    double? engagementScore,
    String? visibility,
    bool? isCollaborative,
    List<String>? collaboratorIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlaylistModel(
      playlistId: playlistId ?? this.playlistId,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      reelIds: reelIds ?? this.reelIds,
      followerCount: followerCount ?? this.followerCount,
      totalViews: totalViews ?? this.totalViews,
      engagementScore: engagementScore ?? this.engagementScore,
      visibility: visibility ?? this.visibility,
      isCollaborative: isCollaborative ?? this.isCollaborative,
      collaboratorIds: collaboratorIds ?? this.collaboratorIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class ReelModel {
  final String reelId;
  final String creatorUid;
  final String videoUrl;
  final String thumbnailUrl;
  final String cloudinaryPublicId;
  final String caption;
  final List<String> hashtags;
  final String visibility; // public, followers, private
  final int likesCount;
  final int commentsCount;
  final int viewsCount;
  final double completionRate;
  final DateTime createdAt;
  final bool isActive;

  ReelModel({
    required this.reelId,
    required this.creatorUid,
    required this.videoUrl,
    this.thumbnailUrl = '',
    this.cloudinaryPublicId = '',
    this.caption = '',
    List<String>? hashtags,
    this.visibility = 'public',
    this.likesCount = 0,
    this.commentsCount = 0,
    this.viewsCount = 0,
    this.completionRate = 0.0,
    DateTime? createdAt,
    this.isActive = true,
  })  : hashtags = hashtags ?? [],
        createdAt = createdAt ?? DateTime.now();

  factory ReelModel.fromMap(Map<String, dynamic> map) {
    return ReelModel(
      reelId: map['reelId'] ?? '',
      creatorUid: map['creatorUid'] ?? '',
      videoUrl: map['videoUrl'] ?? '',
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      cloudinaryPublicId: map['cloudinaryPublicId'] ?? '',
      caption: map['caption'] ?? '',
      hashtags: List<String>.from(map['hashtags'] ?? []),
      visibility: map['visibility'] ?? 'public',
      likesCount: map['likesCount'] ?? 0,
      commentsCount: map['commentsCount'] ?? 0,
      viewsCount: map['viewsCount'] ?? 0,
      completionRate: (map['completionRate'] ?? 0.0).toDouble(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reelId': reelId,
      'creatorUid': creatorUid,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'cloudinaryPublicId': cloudinaryPublicId,
      'caption': caption,
      'hashtags': hashtags,
      'visibility': visibility,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'viewsCount': viewsCount,
      'completionRate': completionRate,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

  ReelModel copyWith({
    String? reelId,
    String? creatorUid,
    String? videoUrl,
    String? thumbnailUrl,
    String? cloudinaryPublicId,
    String? caption,
    List<String>? hashtags,
    String? visibility,
    int? likesCount,
    int? commentsCount,
    int? viewsCount,
    double? completionRate,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return ReelModel(
      reelId: reelId ?? this.reelId,
      creatorUid: creatorUid ?? this.creatorUid,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      cloudinaryPublicId: cloudinaryPublicId ?? this.cloudinaryPublicId,
      caption: caption ?? this.caption,
      hashtags: hashtags ?? this.hashtags,
      visibility: visibility ?? this.visibility,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      viewsCount: viewsCount ?? this.viewsCount,
      completionRate: completionRate ?? this.completionRate,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

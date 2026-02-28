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
  final List<String> taggedUsers;
  final bool hideLikes;
  final DateTime createdAt;
  final bool isActive;
  // Overlay fields
  final String overlayText;
  final double textX;
  final double textY;
  final double textScale;
  final String textColor;
  final String filter;
  final List<Map<String, dynamic>> stickers;
  // Music fields
  final String musicUrl;
  final String musicName;
  // Gamification fields
  final bool isLimited;
  final int maxViews;
  final DateTime? expiryTime;
  final double averageRating;
  final int totalRatings;
  final int ratingSum;
  // Lifecycle (Feature 7)
  final String lifecycleStage;
  final double viewVelocity;
  final double engagementGrowthRate;
  final DateTime? lastVelocityCalculation;
  // Content type (Feature 12)
  final String contentType;
  // Community tags (Feature 14)
  final String communityCategory;
  final Map<String, int> categoryVoteCounts;
  // Watch depth (Feature 17)
  final double avgWatchDepth;
  final int totalWatchSessions;
  final int highRetentionViews;
  // Momentum (Feature 19)
  final double momentumScore;
  final double engagementLastHour;
  final double engagementPreviousHour;
  final String momentumStatus;

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
    List<String>? taggedUsers,
    this.hideLikes = false,
    DateTime? createdAt,
    this.isActive = true,
    this.overlayText = '',
    this.textX = 0.5,
    this.textY = 0.3,
    this.textScale = 1.0,
    this.textColor = '#FFFFFF',
    this.filter = 'none',
    this.stickers = const [],
    this.musicUrl = '',
    this.musicName = '',
    this.isLimited = false,
    this.maxViews = 0,
    this.expiryTime,
    this.averageRating = 0.0,
    this.totalRatings = 0,
    this.ratingSum = 0,
    this.lifecycleStage = 'fresh',
    this.viewVelocity = 0.0,
    this.engagementGrowthRate = 0.0,
    this.lastVelocityCalculation,
    this.contentType = 'other',
    this.communityCategory = '',
    Map<String, int>? categoryVoteCounts,
    this.avgWatchDepth = 0.0,
    this.totalWatchSessions = 0,
    this.highRetentionViews = 0,
    this.momentumScore = 0.0,
    this.engagementLastHour = 0.0,
    this.engagementPreviousHour = 0.0,
    this.momentumStatus = 'stable',
  }) : hashtags = hashtags ?? [],
       taggedUsers = taggedUsers ?? [],
       categoryVoteCounts = categoryVoteCounts ?? {},
       createdAt = createdAt ?? DateTime.now();

  bool get hasReachedLimit =>
      isLimited && maxViews > 0 && viewsCount >= maxViews;
  bool get isExpired =>
      expiryTime != null && DateTime.now().isAfter(expiryTime!);

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
      taggedUsers: List<String>.from(map['taggedUsers'] ?? []),
      hideLikes: map['hideLikes'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
      overlayText: map['overlayText'] ?? '',
      textX: (map['textX'] ?? 0.5).toDouble(),
      textY: (map['textY'] ?? 0.3).toDouble(),
      textScale: (map['textScale'] ?? 1.0).toDouble(),
      textColor: map['textColor'] ?? '#FFFFFF',
      filter: map['filter'] ?? 'none',
      stickers: List<Map<String, dynamic>>.from(map['stickers'] ?? []),
      musicUrl: map['musicUrl'] ?? '',
      musicName: map['musicName'] ?? '',
      isLimited: map['isLimited'] ?? false,
      maxViews: map['maxViews'] ?? 0,
      expiryTime: (map['expiryTime'] as Timestamp?)?.toDate(),
      averageRating: (map['averageRating'] ?? 0.0).toDouble(),
      totalRatings: map['totalRatings'] ?? 0,
      ratingSum: map['ratingSum'] ?? 0,
      lifecycleStage: map['lifecycleStage'] ?? 'fresh',
      viewVelocity: (map['viewVelocity'] ?? 0.0).toDouble(),
      engagementGrowthRate: (map['engagementGrowthRate'] ?? 0.0).toDouble(),
      lastVelocityCalculation: (map['lastVelocityCalculation'] as Timestamp?)?.toDate(),
      contentType: map['contentType'] ?? 'other',
      communityCategory: map['communityCategory'] ?? '',
      categoryVoteCounts: Map<String, int>.from(map['categoryVoteCounts'] ?? {}),
      avgWatchDepth: (map['avgWatchDepth'] ?? 0.0).toDouble(),
      totalWatchSessions: map['totalWatchSessions'] ?? 0,
      highRetentionViews: map['highRetentionViews'] ?? 0,
      momentumScore: (map['momentumScore'] ?? 0.0).toDouble(),
      engagementLastHour: (map['engagementLastHour'] ?? 0.0).toDouble(),
      engagementPreviousHour: (map['engagementPreviousHour'] ?? 0.0).toDouble(),
      momentumStatus: map['momentumStatus'] ?? 'stable',
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
      'taggedUsers': taggedUsers,
      'hideLikes': hideLikes,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'overlayText': overlayText,
      'textX': textX,
      'textY': textY,
      'textScale': textScale,
      'textColor': textColor,
      'filter': filter,
      'stickers': stickers,
      'musicUrl': musicUrl,
      'musicName': musicName,
      'isLimited': isLimited,
      'maxViews': maxViews,
      'expiryTime': expiryTime != null ? Timestamp.fromDate(expiryTime!) : null,
      'averageRating': averageRating,
      'totalRatings': totalRatings,
      'ratingSum': ratingSum,
      'lifecycleStage': lifecycleStage,
      'viewVelocity': viewVelocity,
      'engagementGrowthRate': engagementGrowthRate,
      'lastVelocityCalculation': lastVelocityCalculation != null
          ? Timestamp.fromDate(lastVelocityCalculation!)
          : null,
      'contentType': contentType,
      'communityCategory': communityCategory,
      'categoryVoteCounts': categoryVoteCounts,
      'avgWatchDepth': avgWatchDepth,
      'totalWatchSessions': totalWatchSessions,
      'highRetentionViews': highRetentionViews,
      'momentumScore': momentumScore,
      'engagementLastHour': engagementLastHour,
      'engagementPreviousHour': engagementPreviousHour,
      'momentumStatus': momentumStatus,
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
    List<String>? taggedUsers,
    bool? hideLikes,
    DateTime? createdAt,
    bool? isActive,
    String? overlayText,
    double? textX,
    double? textY,
    double? textScale,
    String? textColor,
    String? filter,
    List<Map<String, dynamic>>? stickers,
    String? musicUrl,
    String? musicName,
    bool? isLimited,
    int? maxViews,
    DateTime? expiryTime,
    double? averageRating,
    int? totalRatings,
    int? ratingSum,
    String? lifecycleStage,
    double? viewVelocity,
    double? engagementGrowthRate,
    DateTime? lastVelocityCalculation,
    String? contentType,
    String? communityCategory,
    Map<String, int>? categoryVoteCounts,
    double? avgWatchDepth,
    int? totalWatchSessions,
    int? highRetentionViews,
    double? momentumScore,
    double? engagementLastHour,
    double? engagementPreviousHour,
    String? momentumStatus,
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
      taggedUsers: taggedUsers ?? this.taggedUsers,
      hideLikes: hideLikes ?? this.hideLikes,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      overlayText: overlayText ?? this.overlayText,
      textX: textX ?? this.textX,
      textY: textY ?? this.textY,
      textScale: textScale ?? this.textScale,
      textColor: textColor ?? this.textColor,
      filter: filter ?? this.filter,
      stickers: stickers ?? this.stickers,
      musicUrl: musicUrl ?? this.musicUrl,
      musicName: musicName ?? this.musicName,
      isLimited: isLimited ?? this.isLimited,
      maxViews: maxViews ?? this.maxViews,
      expiryTime: expiryTime ?? this.expiryTime,
      averageRating: averageRating ?? this.averageRating,
      totalRatings: totalRatings ?? this.totalRatings,
      ratingSum: ratingSum ?? this.ratingSum,
      lifecycleStage: lifecycleStage ?? this.lifecycleStage,
      viewVelocity: viewVelocity ?? this.viewVelocity,
      engagementGrowthRate: engagementGrowthRate ?? this.engagementGrowthRate,
      lastVelocityCalculation: lastVelocityCalculation ?? this.lastVelocityCalculation,
      contentType: contentType ?? this.contentType,
      communityCategory: communityCategory ?? this.communityCategory,
      categoryVoteCounts: categoryVoteCounts ?? this.categoryVoteCounts,
      avgWatchDepth: avgWatchDepth ?? this.avgWatchDepth,
      totalWatchSessions: totalWatchSessions ?? this.totalWatchSessions,
      highRetentionViews: highRetentionViews ?? this.highRetentionViews,
      momentumScore: momentumScore ?? this.momentumScore,
      engagementLastHour: engagementLastHour ?? this.engagementLastHour,
      engagementPreviousHour: engagementPreviousHour ?? this.engagementPreviousHour,
      momentumStatus: momentumStatus ?? this.momentumStatus,
    );
  }
}

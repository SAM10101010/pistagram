import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String creatorUid;
  final List<String> mediaUrls;       // Multiple images or mixed
  final List<String> cloudinaryIds;   // For deletion
  final String mediaType;             // 'image', 'video', 'mixed'
  final String caption;
  final List<String> hashtags;
  final String visibility;            // 'public', 'followers', 'private'
  final int likesCount;
  final int commentsCount;
  final bool allowComments;
  final String location;
  final List<String> taggedUsers;
  final bool hideLikes;
  final bool hideComments;
  final bool isActive;
  final DateTime createdAt;
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

  PostModel({
    required this.postId,
    required this.creatorUid,
    required this.mediaUrls,
    this.cloudinaryIds = const [],
    this.mediaType = 'image',
    this.caption = '',
    List<String>? hashtags,
    this.visibility = 'public',
    this.likesCount = 0,
    this.commentsCount = 0,
    this.allowComments = true,
    this.location = '',
    List<String>? taggedUsers,
    this.hideLikes = false,
    this.hideComments = false,
    this.isActive = true,
    DateTime? createdAt,
    this.overlayText = '',
    this.textX = 0.5,
    this.textY = 0.3,
    this.textScale = 1.0,
    this.textColor = '#FFFFFF',
    this.filter = 'none',
    this.stickers = const [],
    this.musicUrl = '',
    this.musicName = '',
  })  : hashtags = hashtags ?? [],
        taggedUsers = taggedUsers ?? [],
        createdAt = createdAt ?? DateTime.now();

  factory PostModel.fromMap(Map<String, dynamic> map) {
    return PostModel(
      postId: map['postId'] ?? '',
      creatorUid: map['creatorUid'] ?? '',
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      cloudinaryIds: List<String>.from(map['cloudinaryIds'] ?? []),
      mediaType: map['mediaType'] ?? 'image',
      caption: map['caption'] ?? '',
      hashtags: List<String>.from(map['hashtags'] ?? []),
      visibility: map['visibility'] ?? 'public',
      likesCount: map['likesCount'] ?? 0,
      commentsCount: map['commentsCount'] ?? 0,
      allowComments: map['allowComments'] ?? true,
      location: map['location'] ?? '',
      taggedUsers: List<String>.from(map['taggedUsers'] ?? []),
      hideLikes: map['hideLikes'] ?? false,
      hideComments: map['hideComments'] ?? false,
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      overlayText: map['overlayText'] ?? '',
      textX: (map['textX'] ?? 0.5).toDouble(),
      textY: (map['textY'] ?? 0.3).toDouble(),
      textScale: (map['textScale'] ?? 1.0).toDouble(),
      textColor: map['textColor'] ?? '#FFFFFF',
      filter: map['filter'] ?? 'none',
      stickers: List<Map<String, dynamic>>.from(map['stickers'] ?? []),
      musicUrl: map['musicUrl'] ?? '',
      musicName: map['musicName'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'creatorUid': creatorUid,
      'mediaUrls': mediaUrls,
      'cloudinaryIds': cloudinaryIds,
      'mediaType': mediaType,
      'caption': caption,
      'hashtags': hashtags,
      'visibility': visibility,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'allowComments': allowComments,
      'location': location,
      'taggedUsers': taggedUsers,
      'hideLikes': hideLikes,
      'hideComments': hideComments,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'overlayText': overlayText,
      'textX': textX,
      'textY': textY,
      'textScale': textScale,
      'textColor': textColor,
      'filter': filter,
      'stickers': stickers,
      'musicUrl': musicUrl,
      'musicName': musicName,
    };
  }

  PostModel copyWith({
    String? postId,
    String? creatorUid,
    List<String>? mediaUrls,
    List<String>? cloudinaryIds,
    String? mediaType,
    String? caption,
    List<String>? hashtags,
    String? visibility,
    int? likesCount,
    int? commentsCount,
    bool? allowComments,
    String? location,
    List<String>? taggedUsers,
    bool? hideLikes,
    bool? hideComments,
    bool? isActive,
    DateTime? createdAt,
    String? overlayText,
    double? textX,
    double? textY,
    double? textScale,
    String? textColor,
    String? filter,
    List<Map<String, dynamic>>? stickers,
    String? musicUrl,
    String? musicName,
  }) {
    return PostModel(
      postId: postId ?? this.postId,
      creatorUid: creatorUid ?? this.creatorUid,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      cloudinaryIds: cloudinaryIds ?? this.cloudinaryIds,
      mediaType: mediaType ?? this.mediaType,
      caption: caption ?? this.caption,
      hashtags: hashtags ?? this.hashtags,
      visibility: visibility ?? this.visibility,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      allowComments: allowComments ?? this.allowComments,
      location: location ?? this.location,
      taggedUsers: taggedUsers ?? this.taggedUsers,
      hideLikes: hideLikes ?? this.hideLikes,
      hideComments: hideComments ?? this.hideComments,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      overlayText: overlayText ?? this.overlayText,
      textX: textX ?? this.textX,
      textY: textY ?? this.textY,
      textScale: textScale ?? this.textScale,
      textColor: textColor ?? this.textColor,
      filter: filter ?? this.filter,
      stickers: stickers ?? this.stickers,
      musicUrl: musicUrl ?? this.musicUrl,
      musicName: musicName ?? this.musicName,
    );
  }
}

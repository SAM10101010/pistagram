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
  final bool isActive;
  final DateTime createdAt;

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
    this.isActive = true,
    DateTime? createdAt,
  })  : hashtags = hashtags ?? [],
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
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
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
    bool? isActive,
    DateTime? createdAt,
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
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

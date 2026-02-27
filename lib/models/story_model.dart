import 'package:cloud_firestore/cloud_firestore.dart';

class StoryModel {
  final String storyId;
  final String creatorUid;
  final String mediaUrl;
  final String mediaType;         // 'image' or 'video'
  final String cloudinaryId;
  final String text;              // Text overlay content
  final double textX;             // Text position X (0.0 - 1.0)
  final double textY;             // Text position Y (0.0 - 1.0)
  final double textScale;         // Text scale factor
  final String textColor;         // Hex color
  final String filter;            // Filter name applied
  final List<Map<String, dynamic>> stickers; // [{emoji, x, y, size}]
  final String audience;          // 'everyone' or 'close_friends'
  final String musicUrl;
  final String musicName;
  final List<String> viewerUids;
  final int viewCount;
  final DateTime createdAt;
  final DateTime expiresAt;       // 24h after creation

  StoryModel({
    required this.storyId,
    required this.creatorUid,
    required this.mediaUrl,
    this.mediaType = 'image',
    this.cloudinaryId = '',
    this.text = '',
    this.textX = 0.5,
    this.textY = 0.5,
    this.textScale = 1.0,
    this.textColor = '#FFFFFF',
    this.filter = 'none',
    this.stickers = const [],
    this.audience = 'everyone',
    this.musicUrl = '',
    this.musicName = '',
    this.viewerUids = const [],
    this.viewCount = 0,
    DateTime? createdAt,
    DateTime? expiresAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        expiresAt = expiresAt ?? DateTime.now().add(const Duration(hours: 24));

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory StoryModel.fromMap(Map<String, dynamic> map) {
    return StoryModel(
      storyId: map['storyId'] ?? '',
      creatorUid: map['creatorUid'] ?? '',
      mediaUrl: map['mediaUrl'] ?? '',
      mediaType: map['mediaType'] ?? 'image',
      cloudinaryId: map['cloudinaryId'] ?? '',
      text: map['text'] ?? '',
      textX: (map['textX'] ?? 0.5).toDouble(),
      textY: (map['textY'] ?? 0.5).toDouble(),
      textScale: (map['textScale'] ?? 1.0).toDouble(),
      textColor: map['textColor'] ?? '#FFFFFF',
      filter: map['filter'] ?? 'none',
      stickers: List<Map<String, dynamic>>.from(map['stickers'] ?? []),
      audience: map['audience'] ?? 'everyone',
      musicUrl: map['musicUrl'] ?? '',
      musicName: map['musicName'] ?? '',
      viewerUids: List<String>.from(map['viewerUids'] ?? []),
      viewCount: map['viewCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(hours: 24)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storyId': storyId,
      'creatorUid': creatorUid,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'cloudinaryId': cloudinaryId,
      'text': text,
      'textX': textX,
      'textY': textY,
      'textScale': textScale,
      'textColor': textColor,
      'filter': filter,
      'stickers': stickers,
      'audience': audience,
      'musicUrl': musicUrl,
      'musicName': musicName,
      'viewerUids': viewerUids,
      'viewCount': viewCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  StoryModel copyWith({
    String? storyId,
    String? creatorUid,
    String? mediaUrl,
    String? mediaType,
    String? cloudinaryId,
    String? text,
    double? textX,
    double? textY,
    double? textScale,
    String? textColor,
    String? filter,
    List<Map<String, dynamic>>? stickers,
    String? audience,
    String? musicUrl,
    String? musicName,
    List<String>? viewerUids,
    int? viewCount,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return StoryModel(
      storyId: storyId ?? this.storyId,
      creatorUid: creatorUid ?? this.creatorUid,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      cloudinaryId: cloudinaryId ?? this.cloudinaryId,
      text: text ?? this.text,
      textX: textX ?? this.textX,
      textY: textY ?? this.textY,
      textScale: textScale ?? this.textScale,
      textColor: textColor ?? this.textColor,
      filter: filter ?? this.filter,
      stickers: stickers ?? this.stickers,
      audience: audience ?? this.audience,
      musicUrl: musicUrl ?? this.musicUrl,
      musicName: musicName ?? this.musicName,
      viewerUids: viewerUids ?? this.viewerUids,
      viewCount: viewCount ?? this.viewCount,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

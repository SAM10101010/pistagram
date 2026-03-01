import 'package:cloud_firestore/cloud_firestore.dart';

class WarningModel {
  final String warningId;
  final String userId;
  final int level; // 1=Notice, 2=Temp restriction, 3=Suspension
  final String type; // spam, harassment, manipulation, content_violation, fraud, other
  final String title;
  final String description;
  final List<String> evidence;
  final String contentId;
  final String contentType; // reel, comment, post
  final String actionTaken;
  final DateTime? expiresAt;
  final DateTime? acknowledgedAt;
  final bool acknowledgedByUser;
  final String issuedBy; // adminId or 'system'
  final String issuedByEmail;
  final String status; // active, expired, acknowledged, revoked
  final DateTime createdAt;
  final DateTime updatedAt;

  WarningModel({
    required this.warningId,
    required this.userId,
    required this.level,
    this.type = '',
    this.title = '',
    this.description = '',
    List<String>? evidence,
    this.contentId = '',
    this.contentType = '',
    this.actionTaken = 'none',
    this.expiresAt,
    this.acknowledgedAt,
    this.acknowledgedByUser = false,
    this.issuedBy = 'system',
    this.issuedByEmail = '',
    this.status = 'active',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : evidence = evidence ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory WarningModel.fromMap(Map<String, dynamic> map) {
    return WarningModel(
      warningId: map['warningId'] ?? '',
      userId: map['userId'] ?? '',
      level: map['level'] ?? 1,
      type: map['type'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      evidence: List<String>.from(map['evidence'] ?? []),
      contentId: map['contentId'] ?? '',
      contentType: map['contentType'] ?? '',
      actionTaken: map['actionTaken'] ?? 'none',
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
      acknowledgedAt: (map['acknowledgedAt'] as Timestamp?)?.toDate(),
      acknowledgedByUser: map['acknowledgedByUser'] ?? false,
      issuedBy: map['issuedBy'] ?? 'system',
      issuedByEmail: map['issuedByEmail'] ?? '',
      status: map['status'] ?? 'active',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'warningId': warningId,
      'userId': userId,
      'level': level,
      'type': type,
      'title': title,
      'description': description,
      'evidence': evidence,
      'contentId': contentId,
      'contentType': contentType,
      'actionTaken': actionTaken,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'acknowledgedAt': acknowledgedAt != null ? Timestamp.fromDate(acknowledgedAt!) : null,
      'acknowledgedByUser': acknowledgedByUser,
      'issuedBy': issuedBy,
      'issuedByEmail': issuedByEmail,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  String get levelLabel {
    switch (level) {
      case 1:
        return 'Notice';
      case 2:
        return 'Restriction';
      case 3:
        return 'Suspension';
      default:
        return 'Unknown';
    }
  }

  WarningModel copyWith({
    String? warningId,
    String? userId,
    int? level,
    String? type,
    String? title,
    String? description,
    List<String>? evidence,
    String? contentId,
    String? contentType,
    String? actionTaken,
    DateTime? expiresAt,
    DateTime? acknowledgedAt,
    bool? acknowledgedByUser,
    String? issuedBy,
    String? issuedByEmail,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WarningModel(
      warningId: warningId ?? this.warningId,
      userId: userId ?? this.userId,
      level: level ?? this.level,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      evidence: evidence ?? this.evidence,
      contentId: contentId ?? this.contentId,
      contentType: contentType ?? this.contentType,
      actionTaken: actionTaken ?? this.actionTaken,
      expiresAt: expiresAt ?? this.expiresAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      acknowledgedByUser: acknowledgedByUser ?? this.acknowledgedByUser,
      issuedBy: issuedBy ?? this.issuedBy,
      issuedByEmail: issuedByEmail ?? this.issuedByEmail,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

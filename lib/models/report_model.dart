import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String reporterUid;
  final String targetType; // user, reel, comment
  final String targetId;
  final String reason;
  final String status; // pending, reviewed, actioned
  final DateTime createdAt;

  ReportModel({
    required this.id,
    required this.reporterUid,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.status = 'pending',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ReportModel.fromMap(Map<String, dynamic> map) {
    return ReportModel(
      id: map['id'] ?? '',
      reporterUid: map['reporterUid'] ?? '',
      targetType: map['targetType'] ?? '',
      targetId: map['targetId'] ?? '',
      reason: map['reason'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reporterUid': reporterUid,
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

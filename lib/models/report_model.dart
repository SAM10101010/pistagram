import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String reporterUid;
  final String targetType; // user, reel, comment
  final String targetId;
  final String reason;
  final String status; // pending, reviewed, actioned
  final DateTime createdAt;
  final int validVotes;
  final int invalidVotes;
  final int totalVotes;

  ReportModel({
    required this.id,
    required this.reporterUid,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.status = 'pending',
    this.validVotes = 0,
    this.invalidVotes = 0,
    this.totalVotes = 0,
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
      validVotes: map['validVotes'] ?? 0,
      invalidVotes: map['invalidVotes'] ?? 0,
      totalVotes: map['totalVotes'] ?? 0,
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
      'validVotes': validVotes,
      'invalidVotes': invalidVotes,
      'totalVotes': totalVotes,
    };
  }
}

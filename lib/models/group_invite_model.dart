import 'package:cloud_firestore/cloud_firestore.dart';

class GroupInviteModel {
  final String id;
  final String groupId;
  final String groupName;
  final String inviterUid;
  final String inviteeUid;
  final String status; // pending, accepted, declined
  final DateTime createdAt;

  GroupInviteModel({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.inviterUid,
    required this.inviteeUid,
    this.status = 'pending',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory GroupInviteModel.fromMap(Map<String, dynamic> map) {
    return GroupInviteModel(
      id: map['id'] ?? '',
      groupId: map['groupId'] ?? '',
      groupName: map['groupName'] ?? '',
      inviterUid: map['inviterUid'] ?? '',
      inviteeUid: map['inviteeUid'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'groupName': groupName,
      'inviterUid': inviterUid,
      'inviteeUid': inviteeUid,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

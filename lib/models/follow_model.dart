import 'package:cloud_firestore/cloud_firestore.dart';

class FollowModel {
  final String followerId;
  final String followingId;
  final String status; // accepted, pending, rejected
  final DateTime createdAt;

  FollowModel({
    required this.followerId,
    required this.followingId,
    this.status = 'accepted',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory FollowModel.fromMap(Map<String, dynamic> map) {
    return FollowModel(
      followerId: map['followerId'] ?? '',
      followingId: map['followingId'] ?? '',
      status: map['status'] ?? 'accepted',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'followerId': followerId,
      'followingId': followingId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

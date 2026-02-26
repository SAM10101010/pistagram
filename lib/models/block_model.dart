import 'package:cloud_firestore/cloud_firestore.dart';

class BlockModel {
  final String blockerUid;
  final String blockedUid;
  final DateTime createdAt;

  BlockModel({
    required this.blockerUid,
    required this.blockedUid,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory BlockModel.fromMap(Map<String, dynamic> map) {
    return BlockModel(
      blockerUid: map['blockerUid'] ?? '',
      blockedUid: map['blockedUid'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'blockerUid': blockerUid,
      'blockedUid': blockedUid,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

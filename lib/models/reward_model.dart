import 'package:cloud_firestore/cloud_firestore.dart';

class RewardModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final int pointsCost;
  final int stock;
  final DateTime? expiryDate;
  final bool isActive;
  final DateTime createdAt;

  RewardModel({
    required this.id,
    required this.title,
    this.description = '',
    this.imageUrl = '',
    required this.pointsCost,
    this.stock = -1, // -1 = unlimited
    this.expiryDate,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory RewardModel.fromMap(Map<String, dynamic> map) {
    return RewardModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      pointsCost: map['pointsCost'] ?? 0,
      stock: map['stock'] ?? -1,
      expiryDate: (map['expiryDate'] as Timestamp?)?.toDate(),
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'pointsCost': pointsCost,
      'stock': stock,
      'expiryDate':
          expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class RedemptionModel {
  final String id;
  final String uid;
  final String rewardId;
  final String rewardTitle;
  final int pointsSpent;
  final String status; // pending, fulfilled, cancelled
  final DateTime createdAt;

  RedemptionModel({
    required this.id,
    required this.uid,
    required this.rewardId,
    required this.rewardTitle,
    required this.pointsSpent,
    this.status = 'pending',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory RedemptionModel.fromMap(Map<String, dynamic> map) {
    return RedemptionModel(
      id: map['id'] ?? '',
      uid: map['uid'] ?? '',
      rewardId: map['rewardId'] ?? '',
      rewardTitle: map['rewardTitle'] ?? '',
      pointsSpent: map['pointsSpent'] ?? 0,
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'rewardId': rewardId,
      'rewardTitle': rewardTitle,
      'pointsSpent': pointsSpent,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

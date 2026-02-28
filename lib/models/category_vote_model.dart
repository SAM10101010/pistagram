import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryVoteModel {
  final String id; // {reelId}_{voterId}
  final String reelId;
  final String voterId;
  final String category;
  final DateTime createdAt;

  CategoryVoteModel({
    required this.id,
    required this.reelId,
    required this.voterId,
    required this.category,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory CategoryVoteModel.fromMap(Map<String, dynamic> map) {
    return CategoryVoteModel(
      id: map['id'] ?? '',
      reelId: map['reelId'] ?? '',
      voterId: map['voterId'] ?? '',
      category: map['category'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reelId': reelId,
      'voterId': voterId,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

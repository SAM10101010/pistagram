import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String uid;
  final String type; // earned, bonus, redeemed, locked
  final int amount;
  final String reason;
  final String reelId;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.uid,
    required this.type,
    required this.amount,
    this.reason = '',
    this.reelId = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] ?? '',
      uid: map['uid'] ?? '',
      type: map['type'] ?? 'earned',
      amount: map['amount'] ?? 0,
      reason: map['reason'] ?? '',
      reelId: map['reelId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'type': type,
      'amount': amount,
      'reason': reason,
      'reelId': reelId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  TransactionModel copyWith({
    String? id,
    String? uid,
    String? type,
    int? amount,
    String? reason,
    String? reelId,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      reelId: reelId ?? this.reelId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class PointTransferModel {
  final String id;
  final String senderId;
  final String receiverId;
  final int grossAmount;
  final int fee;
  final int netAmount;
  final DateTime createdAt;

  PointTransferModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.grossAmount,
    required this.fee,
    required this.netAmount,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PointTransferModel.fromMap(Map<String, dynamic> map) {
    return PointTransferModel(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      grossAmount: map['grossAmount'] ?? 0,
      fee: map['fee'] ?? 0,
      netAmount: map['netAmount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'grossAmount': grossAmount,
      'fee': fee,
      'netAmount': netAmount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

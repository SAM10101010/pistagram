import 'package:cloud_firestore/cloud_firestore.dart';

class RelationshipScoreModel {
  final String id; // {userA}_{userB} alphabetically sorted
  final String userA;
  final String userB;
  final int commentsExchanged;
  final int reelSharesExchanged;
  final int mutualLikes;
  final int dmCount;
  final double score;
  final DateTime lastUpdated;

  RelationshipScoreModel({
    required this.id,
    required this.userA,
    required this.userB,
    this.commentsExchanged = 0,
    this.reelSharesExchanged = 0,
    this.mutualLikes = 0,
    this.dmCount = 0,
    this.score = 0.0,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  double calculateScore() {
    return (commentsExchanged * 3) + (reelSharesExchanged * 5) + (mutualLikes * 2) + (dmCount * 1).toDouble();
  }

  String get relationshipLabel {
    if (score >= 50) return 'Close Connection';
    if (score >= 20) return 'Frequent Interactor';
    if (score >= 5) return 'Acquaintance';
    return '';
  }

  factory RelationshipScoreModel.fromMap(Map<String, dynamic> map) {
    return RelationshipScoreModel(
      id: map['id'] ?? '',
      userA: map['userA'] ?? '',
      userB: map['userB'] ?? '',
      commentsExchanged: map['commentsExchanged'] ?? 0,
      reelSharesExchanged: map['reelSharesExchanged'] ?? 0,
      mutualLikes: map['mutualLikes'] ?? 0,
      dmCount: map['dmCount'] ?? 0,
      score: (map['score'] ?? 0.0).toDouble(),
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userA': userA,
      'userB': userB,
      'commentsExchanged': commentsExchanged,
      'reelSharesExchanged': reelSharesExchanged,
      'mutualLikes': mutualLikes,
      'dmCount': dmCount,
      'score': score,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}

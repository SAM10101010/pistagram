import 'package:cloud_firestore/cloud_firestore.dart';

class FeatureProposalModel {
  final String proposalId;
  final String title;
  final String description;
  final String category; // ui, feature, improvement, bug
  final String proposedBy;
  final String status; // open, under_review, planned, completed, rejected
  final int votesFor;
  final int votesAgainst;
  final DateTime createdAt;

  FeatureProposalModel({
    required this.proposalId,
    required this.title,
    this.description = '',
    this.category = 'feature',
    required this.proposedBy,
    this.status = 'open',
    this.votesFor = 0,
    this.votesAgainst = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get netVotes => votesFor - votesAgainst;

  factory FeatureProposalModel.fromMap(Map<String, dynamic> map) {
    return FeatureProposalModel(
      proposalId: map['proposalId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'feature',
      proposedBy: map['proposedBy'] ?? '',
      status: map['status'] ?? 'open',
      votesFor: map['votesFor'] ?? 0,
      votesAgainst: map['votesAgainst'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'proposalId': proposalId,
      'title': title,
      'description': description,
      'category': category,
      'proposedBy': proposedBy,
      'status': status,
      'votesFor': votesFor,
      'votesAgainst': votesAgainst,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

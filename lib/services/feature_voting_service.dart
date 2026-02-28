import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/feature_proposal_model.dart';

class FeatureVotingService {
  final _firestore = FirebaseFirestore.instance;

  Future<FeatureProposalModel> createProposal(String title, String description, String category, String proposerId) async {
    final ref = _firestore.collection('featureProposals').doc();
    final proposal = FeatureProposalModel(
      proposalId: ref.id,
      title: title,
      description: description,
      category: category,
      proposedBy: proposerId,
    );
    await ref.set(proposal.toMap());
    return proposal;
  }

  Future<void> voteFor(String proposalId, String voterId) async {
    final voteId = '${proposalId}_$voterId';
    final voteRef = _firestore.collection('featureVotes').doc(voteId);
    final proposalRef = _firestore.collection('featureProposals').doc(proposalId);

    final existingVote = await voteRef.get();
    if (existingVote.exists) {
      final oldVote = existingVote.data()?['vote'] as String?;
      if (oldVote == 'for') return;
      // Change from against to for
      final batch = _firestore.batch();
      batch.update(voteRef, {'vote': 'for'});
      batch.update(proposalRef, {
        'votesFor': FieldValue.increment(1),
        'votesAgainst': FieldValue.increment(-1),
      });
      await batch.commit();
      return;
    }

    final batch = _firestore.batch();
    batch.set(voteRef, {
      'proposalId': proposalId,
      'voterId': voterId,
      'vote': 'for',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(proposalRef, {'votesFor': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> voteAgainst(String proposalId, String voterId) async {
    final voteId = '${proposalId}_$voterId';
    final voteRef = _firestore.collection('featureVotes').doc(voteId);
    final proposalRef = _firestore.collection('featureProposals').doc(proposalId);

    final existingVote = await voteRef.get();
    if (existingVote.exists) {
      final oldVote = existingVote.data()?['vote'] as String?;
      if (oldVote == 'against') return;
      final batch = _firestore.batch();
      batch.update(voteRef, {'vote': 'against'});
      batch.update(proposalRef, {
        'votesFor': FieldValue.increment(-1),
        'votesAgainst': FieldValue.increment(1),
      });
      await batch.commit();
      return;
    }

    final batch = _firestore.batch();
    batch.set(voteRef, {
      'proposalId': proposalId,
      'voterId': voterId,
      'vote': 'against',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(proposalRef, {'votesAgainst': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<String?> getUserVote(String proposalId, String userId) async {
    final voteId = '${proposalId}_$userId';
    final doc = await _firestore.collection('featureVotes').doc(voteId).get();
    if (!doc.exists) return null;
    return doc.data()?['vote'] as String?;
  }

  Future<List<FeatureProposalModel>> getTopProposals({int limit = 20}) async {
    final snapshot = await _firestore
        .collection('featureProposals')
        .where('status', isEqualTo: 'open')
        .orderBy('votesFor', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((d) => FeatureProposalModel.fromMap(d.data())).toList();
  }

  Future<void> updateProposalStatus(String proposalId, String status) async {
    await _firestore.collection('featureProposals').doc(proposalId).update({
      'status': status,
    });
  }
}

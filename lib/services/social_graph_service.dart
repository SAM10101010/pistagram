import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class SocialGraphService {
  final _firestore = FirebaseFirestore.instance;

  Future<List<String>> _getFollowerIds(String userId) async {
    final snapshot = await _firestore
        .collection('follows')
        .where('followingId', isEqualTo: userId)
        .get();
    return snapshot.docs.map((d) => d.data()['followerId'] as String).toList();
  }

  Future<List<String>> _getFollowingIds(String userId) async {
    final snapshot = await _firestore
        .collection('follows')
        .where('followerId', isEqualTo: userId)
        .get();
    return snapshot.docs.map((d) => d.data()['followingId'] as String).toList();
  }

  Future<List<UserModel>> getMutualFollowers(String userA, String userB) async {
    final followersA = await _getFollowerIds(userA);
    final followersB = await _getFollowerIds(userB);

    final mutualIds = followersA.where((id) => followersB.contains(id)).toList();

    if (mutualIds.isEmpty) return [];

    final List<UserModel> mutuals = [];
    for (final uid in mutualIds.take(50)) {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        mutuals.add(UserModel.fromMap(doc.data()!));
      }
    }
    return mutuals;
  }

  Future<int> getMutualFollowersCount(String userA, String userB) async {
    final followersA = await _getFollowerIds(userA);
    final followersB = await _getFollowerIds(userB);
    return followersA.where((id) => followersB.contains(id)).length;
  }

  Future<List<UserModel>> getSharedCircle(String userA, String userB) async {
    final followingA = await _getFollowingIds(userA);
    final followingB = await _getFollowingIds(userB);

    final sharedIds = followingA.where((id) => followingB.contains(id)).toList();

    if (sharedIds.isEmpty) return [];

    final List<UserModel> shared = [];
    for (final uid in sharedIds.take(50)) {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        shared.add(UserModel.fromMap(doc.data()!));
      }
    }
    return shared;
  }

  Future<Map<String, dynamic>> getConnectionSummary(String viewerId, String profileId) async {
    final mutualCount = await getMutualFollowersCount(viewerId, profileId);
    final mutuals = await getMutualFollowers(viewerId, profileId);
    final previewUsers = mutuals.take(3).toList();

    return {
      'mutualCount': mutualCount,
      'previewUsers': previewUsers,
      'hasConnection': mutualCount > 0,
    };
  }
}

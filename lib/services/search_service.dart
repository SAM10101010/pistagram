import '../models/user_model.dart';
import '../models/reel_model.dart';
import 'firestore_service.dart';

class SearchService {
  final FirestoreService _firestoreService = FirestoreService();

  /// Search users — filter out blocked users
  Future<List<UserModel>> searchUsers(String query, {String? currentUid}) async {
    final users = await _firestoreService.searchUsers(query);

    if (currentUid == null) return users;

    // Filter out blocked users and suspended/deleted accounts
    final blockedUids = await _firestoreService.getBlockedUids(currentUid);
    return users.where((u) {
      if (blockedUids.contains(u.uid)) return false;
      if (u.accountStatus != 'active') return false;
      return true;
    }).toList();
  }

  /// Search reels by hashtag — filter out private accounts + blocked users
  Future<List<ReelModel>> searchReelsByHashtag(String hashtag, {int limit = 20, String? currentUid}) async {
    final reels = await _firestoreService.getReelsByHashtag(hashtag, limit: limit * 2);

    if (currentUid == null) return reels.take(limit).toList();

    final blockedUids = await _firestoreService.getBlockedUids(currentUid);
    final filtered = <ReelModel>[];
    for (final reel in reels) {
      if (blockedUids.contains(reel.creatorUid)) continue;
      if (reel.visibility != 'public') continue;

      // Never show private account reels in search
      final creator = await _firestoreService.getUser(reel.creatorUid);
      if (creator == null) continue;
      if (creator.isPrivate) continue;
      if (creator.accountStatus != 'active') continue;

      filtered.add(reel);
      if (filtered.length >= limit) break;
    }
    return filtered;
  }

  /// Trending reels — only public, no private accounts
  Future<List<ReelModel>> getTrendingReels({int limit = 20, String? currentUid}) async {
    final reels = await _firestoreService.getTrendingReels(limit: limit * 2);

    if (currentUid == null) return reels.take(limit).toList();

    final blockedUids = await _firestoreService.getBlockedUids(currentUid);
    final filtered = <ReelModel>[];
    for (final reel in reels) {
      if (blockedUids.contains(reel.creatorUid)) continue;
      if (reel.visibility != 'public') continue;

      final creator = await _firestoreService.getUser(reel.creatorUid);
      if (creator == null) continue;
      if (creator.isPrivate) continue;
      if (creator.accountStatus != 'active') continue;

      filtered.add(reel);
      if (filtered.length >= limit) break;
    }
    return filtered;
  }

  /// Popular creators — only active public accounts
  Future<List<UserModel>> getPopularCreators({int limit = 10}) async {
    final users = await _firestoreService.searchUsers('');
    final active = users.where((u) => u.accountStatus == 'active').toList();
    active.sort((a, b) => b.followersCount.compareTo(a.followersCount));
    return active.take(limit).toList();
  }
}

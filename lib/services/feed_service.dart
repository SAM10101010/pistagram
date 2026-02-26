import '../models/reel_model.dart';
import 'firestore_service.dart';

class FeedService {
  final FirestoreService _firestoreService = FirestoreService();

  /// Home feed: reels from followed users + public reels fallback
  Future<List<ReelModel>> getHomeFeed(String uid, {int limit = 20}) async {
    final followingUids = await _firestoreService.getFollowingUids(uid);
    final blockedUids = await _firestoreService.getBlockedUids(uid);

    List<ReelModel> reels;
    if (followingUids.isEmpty) {
      reels = await _firestoreService.getPublicReels(limit: limit);
    } else {
      reels = await _firestoreService.getFeedReels(followingUids, limit: limit);
      // Mix in some public/trending if feed is sparse
      if (reels.length < 5) {
        final publicReels = await _firestoreService.getPublicReels(limit: limit);
        reels.addAll(publicReels);
      }
    }

    // Filter out blocked users, private account reels (unless following), and duplicates
    final seen = <String>{};
    reels = reels.where((r) {
      if (seen.contains(r.reelId)) return false;
      if (blockedUids.contains(r.creatorUid)) return false;
      seen.add(r.reelId);
      return true;
    }).toList();

    return reels.take(limit).toList();
  }

  /// Explore feed: ONLY public reels, NO private account reels ever
  Future<List<ReelModel>> getExploreFeed(String uid, {int limit = 20}) async {
    final blockedUids = await _firestoreService.getBlockedUids(uid);
    final reels = await _firestoreService.getTrendingReels(limit: limit * 2);

    // Filter: only public reels, no blocked users, no private accounts
    final filtered = <ReelModel>[];
    for (final reel in reels) {
      if (blockedUids.contains(reel.creatorUid)) continue;
      if (reel.visibility != 'public') continue;

      // Check if creator's account is private — never show in explore
      final creator = await _firestoreService.getUser(reel.creatorUid);
      if (creator == null) continue;
      if (creator.isPrivate) continue;
      if (creator.accountStatus != 'active') continue;

      filtered.add(reel);
      if (filtered.length >= limit) break;
    }

    return filtered;
  }

  /// Following feed: only from people you follow
  Future<List<ReelModel>> getFollowingFeed(String uid, {int limit = 20}) async {
    final followingUids = await _firestoreService.getFollowingUids(uid);
    if (followingUids.isEmpty) return [];
    final blockedUids = await _firestoreService.getBlockedUids(uid);
    final reels = await _firestoreService.getFeedReels(followingUids, limit: limit);
    return reels.where((r) => !blockedUids.contains(r.creatorUid)).toList();
  }
}

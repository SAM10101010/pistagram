import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/reel_model.dart';
import 'firestore_service.dart';

class SearchService {
  final FirestoreService _firestoreService = FirestoreService();

  static const String _historyKey = 'search_history';
  static const int _maxHistory = 20;

  // ─── Search History (Local) ───────────────────────────────

  Future<List<String>> getSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_historyKey) ?? [];
  }

  Future<void> addToHistory(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? [];
    history.remove(trimmed);
    history.insert(0, trimmed);
    if (history.length > _maxHistory) history.removeLast();
    await prefs.setStringList(_historyKey, history);
  }

  Future<void> removeFromHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? [];
    history.remove(query);
    await prefs.setStringList(_historyKey, history);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  // ─── Suggestions ──────────────────────────────────────────

  Future<List<UserModel>> getSuggestions({
    String? currentUid,
    int limit = 10,
  }) async {
    final popular = await getPopularCreators(limit: limit * 2);
    if (currentUid == null) return popular.take(limit).toList();
    final blockedUids = await _firestoreService.getBlockedUids(currentUid);
    return popular
        .where((u) => u.uid != currentUid && !blockedUids.contains(u.uid))
        .take(limit)
        .toList();
  }

  // ─── Search ───────────────────────────────────────────────

  /// Search users — filter out blocked users
  Future<List<UserModel>> searchUsers(
    String query, {
    String? currentUid,
  }) async {
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
  Future<List<ReelModel>> searchReelsByHashtag(
    String hashtag, {
    int limit = 20,
    String? currentUid,
  }) async {
    final reels = await _firestoreService.getReelsByHashtag(
      hashtag,
      limit: limit * 2,
    );

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
  Future<List<ReelModel>> getTrendingReels({
    int limit = 20,
    String? currentUid,
  }) async {
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

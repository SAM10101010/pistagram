import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// App-wide in-memory + persistent cache service.
/// Reduces Firestore reads by caching profiles, feed data, etc.
class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  // In-memory caches
  final Map<String, UserModel> _userCache = {};
  final Map<String, DateTime> _userCacheTimestamps = {};
  final Map<String, dynamic> _dataCache = {};

  static const Duration _userCacheTtl = Duration(minutes: 10);
  static const Duration _dataCacheTtl = Duration(minutes: 5);

  // ═══ USER PROFILE CACHE ═══

  /// Get cached user (memory first, then disk)
  UserModel? getCachedUser(String uid) {
    if (_userCache.containsKey(uid)) {
      final ts = _userCacheTimestamps[uid];
      if (ts != null && DateTime.now().difference(ts) < _userCacheTtl) {
        return _userCache[uid];
      }
    }
    return null;
  }

  /// Cache a user in memory + optionally persist to disk
  void cacheUser(UserModel user, {bool persist = false}) {
    _userCache[user.uid] = user;
    _userCacheTimestamps[user.uid] = DateTime.now();
    if (persist) _persistUser(user);
  }

  /// Load user from disk cache (SharedPreferences)
  Future<UserModel?> loadUserFromDisk(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('user_cache_$uid');
      if (json == null) return null;
      final data = jsonDecode(json) as Map<String, dynamic>;
      final user = UserModel(
        uid: data['uid'] ?? '',
        email: data['email'] ?? '',
        username: data['username'] ?? '',
        displayName: data['displayName'] ?? '',
        bio: data['bio'] ?? '',
        profilePicUrl: data['profilePicUrl'] ?? '',
        accountType: data['accountType'] ?? 'public',
        followersCount: data['followersCount'] ?? 0,
        followingCount: data['followingCount'] ?? 0,
        pointsBalance: data['pointsBalance'] ?? 0,
      );
      _userCache[uid] = user;
      _userCacheTimestamps[uid] = DateTime.now();
      return user;
    } catch (e) {
      debugPrint('CacheService: disk load error: $e');
      return null;
    }
  }

  Future<void> _persistUser(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'uid': user.uid,
        'email': user.email,
        'username': user.username,
        'displayName': user.displayName,
        'bio': user.bio,
        'profilePicUrl': user.profilePicUrl,
        'accountType': user.accountType,
        'followersCount': user.followersCount,
        'followingCount': user.followingCount,
        'pointsBalance': user.pointsBalance,
      };
      await prefs.setString('user_cache_${user.uid}', jsonEncode(data));
    } catch (e) {
      debugPrint('CacheService: persist error: $e');
    }
  }

  /// Batch cache multiple users
  void cacheUsers(List<UserModel> users) {
    for (final user in users) {
      cacheUser(user);
    }
  }

  // ═══ GENERIC DATA CACHE ═══

  /// Get cached data by key
  T? getData<T>(String key) {
    final entry = _dataCache[key];
    if (entry == null) return null;
    final ts = entry['ts'] as DateTime;
    if (DateTime.now().difference(ts) > _dataCacheTtl) {
      _dataCache.remove(key);
      return null;
    }
    return entry['data'] as T?;
  }

  /// Cache data with a key
  void setData(String key, dynamic data) {
    _dataCache[key] = {'data': data, 'ts': DateTime.now()};
  }

  // ═══ INVALIDATION ═══

  /// Invalidate a specific user cache
  void invalidateUser(String uid) {
    _userCache.remove(uid);
    _userCacheTimestamps.remove(uid);
  }

  /// Invalidate a data cache entry
  void invalidateData(String key) {
    _dataCache.remove(key);
  }

  /// Clear all in-memory caches
  void clearAll() {
    _userCache.clear();
    _userCacheTimestamps.clear();
    _dataCache.clear();
  }

  /// Clear all persistent caches
  Future<void> clearDiskCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('user_cache_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/follow_service.dart';
import '../services/search_service.dart';
import '../utils/animations.dart';
import 'profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  final _followService = FollowService();
  final _searchService = SearchService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<UserModel> _results = [];
  List<String> _searchHistory = [];
  List<UserModel> _suggestions = [];
  Set<String> _followingIds = {};
  bool _searching = false;
  bool _loaded = false;
  bool _loadingSuggestions = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final uid = _auth.currentUser?.uid ?? '';
    try {
      final results = await Future.wait([
        _firestore.getFollowingUids(uid),
        _searchService.getSearchHistory(),
        _searchService.getSuggestions(currentUid: uid, limit: 10),
      ]);
      _followingIds = (results[0] as List<String>).toSet();
      _searchHistory = results[1] as List<String>;
      _suggestions = results[2] as List<UserModel>;
    } catch (_) {}
    if (mounted) setState(() => _loadingSuggestions = false);
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _loaded = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      _results = await _firestore.searchUsers(query.trim());
      final myUid = _auth.currentUser?.uid ?? '';
      _results.removeWhere((u) => u.uid == myUid);
      // Save to history
      await _searchService.addToHistory(query.trim());
      _searchHistory = await _searchService.getSearchHistory();
    } catch (e) {
      debugPrint('Search error: $e');
    }
    if (mounted) {
      setState(() {
        _searching = false;
        _loaded = true;
      });
    }
  }

  Future<void> _removeHistoryItem(String query) async {
    await _searchService.removeFromHistory(query);
    _searchHistory = await _searchService.getSearchHistory();
    if (mounted) setState(() {});
  }

  Future<void> _clearAllHistory() async {
    await _searchService.clearHistory();
    _searchHistory = [];
    if (mounted) setState(() {});
  }

  Future<void> _toggleFollow(String targetUid) async {
    final uid = _auth.currentUser?.uid ?? '';
    if (_followingIds.contains(targetUid)) {
      await _followService.unfollowUser(uid, targetUid);
      _followingIds.remove(targetUid);
    } else {
      await _followService.followUser(uid, targetUid);
      _followingIds.add(targetUid);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D0D)
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF0D0D0D)
            : const Color(0xFFF8F9FA),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
        ),
        title: Container(
          height: 42,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(15)
                  : Colors.black.withAlpha(15),
            ),
          ),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            style: GoogleFonts.inter(color: textColor, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search users...',
              hintStyle: GoogleFonts.inter(color: subColor, fontSize: 15),
              prefixIcon: Icon(Icons.search_rounded, color: subColor, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _results = [];
                          _loaded = false;
                        });
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        color: subColor,
                        size: 18,
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onSubmitted: _search,
            onChanged: (v) {
              _debounce?.cancel();
              if (v.trim().isEmpty) {
                setState(() {
                  _results = [];
                  _loaded = false;
                });
                return;
              }
              _debounce = Timer(
                const Duration(milliseconds: 400),
                () => _search(v),
              );
            },
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _search(_searchCtrl.text),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.search, color: accent, size: 20),
            ),
          ),
        ],
      ),
      body: _buildBody(accent, isDark, textColor, subColor),
    );
  }

  Widget _buildBody(
    Color accent,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    // Searching state
    if (_searching) {
      return Center(
        child: CircularProgressIndicator(color: accent, strokeWidth: 2),
      );
    }

    // Search results
    if (_loaded && _results.isNotEmpty) {
      return _buildResultsList(accent, isDark, textColor, subColor);
    }

    // No results found
    if (_loaded && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[100],
              ),
              child: Icon(Icons.search_off_rounded, color: subColor, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different username',
              style: GoogleFonts.inter(color: subColor, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Default state: show history + suggestions
    return _buildHistoryAndSuggestions(accent, isDark, textColor, subColor);
  }

  Widget _buildHistoryAndSuggestions(
    Color accent,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      children: [
        // Search History
        if (_searchHistory.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(
                  'Recent Searches',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _clearAllHistory,
                  child: Text(
                    'Clear All',
                    style: GoogleFonts.inter(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ..._searchHistory.map(
            (query) => Container(
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(Icons.history_rounded, color: subColor, size: 22),
                title: Text(
                  query,
                  style: GoogleFonts.inter(color: textColor, fontSize: 14),
                ),
                trailing: IconButton(
                  onPressed: () => _removeHistoryItem(query),
                  icon: Icon(Icons.close_rounded, color: subColor, size: 18),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
                onTap: () {
                  _searchCtrl.text = query;
                  _search(query);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                dense: true,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Suggestions
        if (_suggestions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Suggested for you',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: textColor,
              ),
            ),
          ),
          ..._suggestions.map(
            (user) => _buildUserCard(user, accent, isDark, textColor, subColor),
          ),
        ] else if (_loadingSuggestions) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Suggested for you',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: textColor,
              ),
            ),
          ),
          ...List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const ShimmerLoading(width: 50, height: 50, isCircle: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ShimmerLoading(width: 120, height: 14, borderRadius: 6),
                        SizedBox(height: 6),
                        ShimmerLoading(width: 80, height: 12, borderRadius: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Empty state
        if (_searchHistory.isEmpty &&
            _suggestions.isEmpty &&
            !_loadingSuggestions)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? const Color(0xFF1A1A2E)
                          : Colors.grey[100],
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      color: subColor,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Search for users',
                    style: GoogleFonts.inter(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Find people to follow',
                    style: GoogleFonts.inter(color: subColor, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResultsList(
    Color accent,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: _results.length,
      itemBuilder: (ctx, i) =>
          _buildUserCard(_results[i], accent, isDark, textColor, subColor),
    );
  }

  Widget _buildUserCard(
    UserModel user,
    Color accent,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    final isFollowing = _followingIds.contains(user.uid);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(10)
              : Colors.black.withAlpha(10),
        ),
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          SlideRightRoute(page: ProfileScreen(userId: user.uid)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accent, accent.withAlpha(150)],
                ),
              ),
              padding: const EdgeInsets.all(2),
              child: CircleAvatar(
                backgroundColor: isDark
                    ? const Color(0xFF1A1A2E)
                    : Colors.grey[200],
                backgroundImage: user.profilePicUrl.isNotEmpty
                    ? CachedNetworkImageProvider(user.profilePicUrl)
                    : null,
                child: user.profilePicUrl.isEmpty
                    ? Icon(Icons.person, color: subColor, size: 22)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      fontSize: 15,
                    ),
                  ),
                  if (user.displayName.isNotEmpty)
                    Text(
                      user.displayName,
                      style: GoogleFonts.inter(color: subColor, fontSize: 13),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 34,
              child: ElevatedButton(
                onPressed: () => _toggleFollow(user.uid),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing ? Colors.transparent : accent,
                  side: isFollowing ? BorderSide(color: accent) : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: isFollowing ? 0 : 2,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: GoogleFonts.inter(
                    color: isFollowing ? accent : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

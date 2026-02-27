import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/follow_service.dart';
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
  final _searchCtrl = TextEditingController();

  List<UserModel> _results = [];
  Set<String> _followingIds = {};
  bool _searching = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    try {
      final uid = _auth.currentUser?.uid ?? '';
      final uids = await _firestore.getFollowingUids(uid);
      _followingIds = uids.toSet();
    } catch (_) {}
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _results = []; _loaded = false; });
      return;
    }
    setState(() => _searching = true);
    try {
      _results = await _firestore.searchUsers(query.trim());
      // Remove self from results
      final myUid = _auth.currentUser?.uid ?? '';
      _results.removeWhere((u) => u.uid == myUid);
    } catch (e) {
      debugPrint('Search error: $e');
    }
    if (mounted) setState(() { _searching = false; _loaded = true; });
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
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
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
            border: Border.all(color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(15)),
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
                        setState(() { _results = []; _loaded = false; });
                      },
                      icon: Icon(Icons.close_rounded, color: subColor, size: 18),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onSubmitted: _search,
            onChanged: (v) {
              if (v.isEmpty) setState(() { _results = []; _loaded = false; });
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
      body: _searching
          ? Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2))
          : _loaded && _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[100],
                        ),
                        child: Icon(Icons.search_off_rounded, color: subColor, size: 36),
                      ),
                      const SizedBox(height: 16),
                      Text('No users found', style: GoogleFonts.inter(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Try a different username', style: GoogleFonts.inter(color: subColor, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) {
                    final user = _results[i];
                    final isFollowing = _followingIds.contains(user.uid);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(10)),
                      ),
                      child: GestureDetector(
                        onTap: () => Navigator.push(context, SlideRightRoute(
                          page: ProfileScreen(userId: user.uid),
                        )),
                        child: Row(
                          children: [
                            Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: [accent, accent.withAlpha(150)]),
                              ),
                              padding: const EdgeInsets.all(2),
                              child: CircleAvatar(
                                backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
                                backgroundImage: user.profilePicUrl.isNotEmpty
                                    ? CachedNetworkImageProvider(user.profilePicUrl) : null,
                                child: user.profilePicUrl.isEmpty
                                    ? Icon(Icons.person, color: subColor, size: 22) : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.username, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textColor, fontSize: 15)),
                                  if (user.displayName.isNotEmpty)
                                    Text(user.displayName, style: GoogleFonts.inter(color: subColor, fontSize: 13)),
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
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  elevation: isFollowing ? 0 : 2,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                child: Text(
                                  isFollowing ? 'Following' : 'Follow',
                                  style: GoogleFonts.inter(
                                    color: isFollowing ? accent : Colors.white,
                                    fontSize: 12, fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

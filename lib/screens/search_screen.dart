import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/follow_service.dart';
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
        backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
        ),
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: 'Search users...',
            hintStyle: TextStyle(color: subColor),
            border: InputBorder.none,
          ),
          onSubmitted: _search,
          onChanged: (v) {
            if (v.isEmpty) setState(() { _results = []; _loaded = false; });
          },
        ),
        actions: [
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchCtrl.clear();
                setState(() { _results = []; _loaded = false; });
              },
              icon: Icon(Icons.clear, color: subColor),
            ),
          IconButton(
            onPressed: () => _search(_searchCtrl.text),
            icon: Icon(Icons.search, color: accent),
          ),
        ],
      ),
      body: _searching
          ? Center(child: CircularProgressIndicator(color: accent))
          : _loaded && _results.isEmpty
              ? Center(child: Text('No users found', style: GoogleFonts.inter(color: subColor)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) {
                    final user = _results[i];
                    final isFollowing = _followingIds.contains(user.uid);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
                        backgroundImage: user.profilePicUrl.isNotEmpty
                            ? CachedNetworkImageProvider(user.profilePicUrl) : null,
                        child: user.profilePicUrl.isEmpty
                            ? Icon(Icons.person, color: subColor) : null,
                      ),
                      title: Text(user.username, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textColor)),
                      subtitle: user.displayName.isNotEmpty
                          ? Text(user.displayName, style: GoogleFonts.inter(color: subColor, fontSize: 13))
                          : null,
                      trailing: SizedBox(
                        width: 90, height: 32,
                        child: ElevatedButton(
                          onPressed: () => _toggleFollow(user.uid),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFollowing ? Colors.transparent : accent,
                            side: isFollowing ? BorderSide(color: accent) : null,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: EdgeInsets.zero,
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
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ProfileScreen(userId: user.uid),
                      )),
                    );
                  },
                ),
    );
  }
}

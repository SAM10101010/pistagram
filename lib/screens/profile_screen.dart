import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/reel_model.dart';
import '../models/post_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/follow_service.dart';
import 'edit_profile_screen.dart';
import 'followers_screen.dart';
import 'settings_screen.dart';
import 'post_detail_screen.dart';
import 'chat_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirestoreService _firestore = FirestoreService();
  final FollowService _followService = FollowService();
  late TabController _tabController;
  UserModel? _user;
  List<PostModel> _posts = [];
  List<ReelModel> _reels = [];
  List<ReelModel> _savedReels = [];
  List<ReelModel> _likedReels = [];
  bool _loading = true;
  bool _isFollowing = false;
  bool _isOwn = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCachedProfile();
    _loadProfile();
  }

  /// Load profile from local cache first for instant display
  Future<void> _loadCachedProfile() async {
    try {
      final myUid = _authService.currentUser?.uid ?? '';
      final uid = widget.userId ?? myUid;
      _isOwn = uid == myUid;

      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('profile_cache_$uid');
      if (cachedJson != null) {
        final data = jsonDecode(cachedJson) as Map<String, dynamic>;
        // Restore timestamps as DateTime (stored as ISO strings)
        if (data['createdAt'] is String) {
          data['createdAt'] = null; // let fromMap default
        }
        if (data['updatedAt'] is String) {
          data['updatedAt'] = null;
        }
        _user = UserModel(
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
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Cache load error: $e');
    }
  }

  /// Save profile to local cache
  Future<void> _cacheProfile(UserModel user) async {
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
      await prefs.setString('profile_cache_${user.uid}', jsonEncode(data));
    } catch (e) {
      debugPrint('Cache save error: $e');
    }
  }

  Future<void> _loadProfile() async {
    try {
      final myUid = _authService.currentUser?.uid ?? '';
      final uid = widget.userId ?? myUid;
      _isOwn = uid == myUid;

      // Load user + content in parallel
      final userFuture = _firestore.getUser(uid);
      final reelsFuture = _firestore.getReelsByUser(uid).catchError((_) => <ReelModel>[]);
      final postsFuture = _firestore.getPostsByUser(uid).catchError((_) => <PostModel>[]);

      final results = await Future.wait([userFuture, reelsFuture, postsFuture]);
      _user = results[0] as UserModel?;
      _reels = results[1] as List<ReelModel>;
      _posts = results[2] as List<PostModel>;

      // Cache the profile for next time
      if (_user != null) _cacheProfile(_user!);

      // Check follow status for other profiles
      if (!_isOwn) {
        try {
          final follow = await _firestore.getFollow(myUid, uid);
          _isFollowing = follow != null;
        } catch (e) {
          debugPrint('Error checking follow: $e');
        }
      }

      // Load saved & liked reels for own profile in parallel
      if (_isOwn) {
        final savedFuture = _loadSavedReels(myUid).catchError((_) => <ReelModel>[]);
        final likedFuture = _loadLikedReels(myUid).catchError((_) => <ReelModel>[]);
        final savedLiked = await Future.wait([savedFuture, likedFuture]);
        _savedReels = savedLiked[0];
        _likedReels = savedLiked[1];
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<List<ReelModel>> _loadSavedReels(String uid) async {
    final ids = await _firestore.getSavedReelIds(uid);
    final futures = ids.map((id) => _firestore.getReel(id));
    final results = await Future.wait(futures);
    return results.whereType<ReelModel>().toList();
  }

  Future<List<ReelModel>> _loadLikedReels(String uid) async {
    final ids = await _firestore.getLikedReelIds(uid);
    final futures = ids.map((id) => _firestore.getReel(id));
    final results = await Future.wait(futures);
    return results.whereType<ReelModel>().toList();
  }

  Future<void> _toggleFollow() async {
    final myUid = _authService.currentUser?.uid ?? '';
    final targetUid = widget.userId ?? '';
    if (_isFollowing) {
      await _followService.unfollowUser(myUid, targetUid);
    } else {
      await _followService.followUser(myUid, targetUid);
    }
    _isFollowing = !_isFollowing;
    _loadProfile();
  }

  Future<void> _openChat() async {
    final myUid = _authService.currentUser?.uid ?? '';
    final targetUid = widget.userId ?? '';
    final chat = await _firestore.getOrCreateChat(myUid, targetUid);
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(chatId: chat.chatId, partner: _user),
      ));
    }
  }

  Future<void> _deleteReel(ReelModel reel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reel'),
        content: const Text('Are you sure you want to delete this reel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.deleteReel(reel.reelId);
      _reels.removeWhere((r) => r.reelId == reel.reelId);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reel deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _togglePin(ReelModel reel) async {
    if (_user == null) return;
    final pinned = List<String>.from(_user!.pinnedReelIds);
    if (pinned.contains(reel.reelId)) {
      pinned.remove(reel.reelId);
    } else {
      pinned.insert(0, reel.reelId);
    }
    await _firestore.updateUser(_user!.uid, {'pinnedReelIds': pinned});
    _user = _user!.copyWith(pinnedReelIds: pinned);
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    if (_loading && _user == null) {
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0D0D0D)
            : const Color(0xFFF8F9FA),
        body: Center(child: CircularProgressIndicator(color: accent)),
      );
    }

    // Private account check for non-owner
    final isPrivateAndNotFollowing =
        !_isOwn && (_user?.isPrivate ?? false) && !_isFollowing;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D0D)
          : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildTopBar(accent, isDark, textColor),
                  const SizedBox(height: 16),
                  _buildAvatar(accent, isDark),
                  const SizedBox(height: 12),
                  _buildNameBio(textColor, subColor),
                  const SizedBox(height: 14),
                  _buildActionButtons(accent, isDark, textColor),
                  const SizedBox(height: 18),
                  _buildStats(accent, isDark, textColor, subColor),
                  if (_user?.isPrivate ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline, color: subColor, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Private Account',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: subColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: accent,
                  indicatorWeight: 2.5,
                  labelColor: accent,
                  unselectedLabelColor: subColor,
                  labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(
                      text: 'POSTS',
                      icon: Icon(Icons.grid_on_rounded, size: 20),
                    ),
                    Tab(
                      text: 'REELS',
                      icon: Icon(Icons.video_library_rounded, size: 20),
                    ),
                    Tab(
                      text: 'SAVED',
                      icon: Icon(Icons.bookmark_rounded, size: 20),
                    ),
                    Tab(
                      text: 'LIKED',
                      icon: Icon(Icons.favorite_rounded, size: 20),
                    ),
                  ],
                ),
                isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
              ),
            ),
          ],
          body: isPrivateAndNotFollowing
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 48, color: subColor),
                      const SizedBox(height: 12),
                      Text(
                        'This Account is Private',
                        style: GoogleFonts.inter(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Follow to see their posts',
                        style: GoogleFonts.inter(color: subColor, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPostsGrid(
                      _posts,
                      accent,
                      isDark,
                      showActions: _isOwn,
                    ),
                    _buildReelsGrid(
                      _reels,
                      accent,
                      isDark,
                      showActions: _isOwn,
                    ),
                    _isOwn
                        ? _buildReelsGrid(_savedReels, accent, isDark)
                        : _buildEmptyTab(
                            'Not visible',
                            Icons.lock_outline,
                            subColor,
                          ),
                    _isOwn
                        ? _buildReelsGrid(_likedReels, accent, isDark)
                        : _buildEmptyTab(
                            'Not visible',
                            Icons.lock_outline,
                            subColor,
                          ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTopBar(Color accent, bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (!_isOwn)
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
            ),
          Text(
            _user?.username ?? '@user',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const Spacer(),
          if (_isOwn)
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              icon: Icon(Icons.settings_outlined, color: textColor, size: 24),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(Color accent, bool isDark) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            accent,
            HSLColor.fromColor(
              accent,
            ).withHue((HSLColor.fromColor(accent).hue + 60) % 360).toColor(),
          ],
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: CircleAvatar(
        backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
        backgroundImage: _user != null && _user!.profilePicUrl.isNotEmpty
            ? CachedNetworkImageProvider(_user!.profilePicUrl)
            : null,
        child: _user == null || _user!.profilePicUrl.isEmpty
            ? Icon(Icons.person, size: 40, color: accent)
            : null,
      ),
    );
  }

  Widget _buildNameBio(Color textColor, Color subColor) {
    return Column(
      children: [
        Text(
          _user?.displayName.isNotEmpty == true
              ? _user!.displayName
              : (_user?.username ?? 'User'),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        if (_user != null && _user!.bio.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 40, right: 40),
            child: Text(
              _user!.bio,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: subColor,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons(Color accent, bool isDark, Color textColor) {
    if (_isOwn) {
      return GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditProfileScreen()),
          );
          _loadProfile();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent, width: 1.5),
          ),
          child: Text(
            'Edit Profile',
            style: GoogleFonts.inter(
              color: accent,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    // Other user: Follow + Message buttons
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _toggleFollow,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: _isFollowing
                  ? null
                  : LinearGradient(colors: [accent, accent.withAlpha(200)]),
              border: _isFollowing ? Border.all(color: accent, width: 1.5) : null,
            ),
            child: Text(
              _isFollowing ? 'Following' : 'Follow',
              style: GoogleFonts.inter(
                color: _isFollowing ? accent : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _openChat,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: accent, width: 1.5),
            ),
            child: Text(
              'Message',
              style: GoogleFonts.inter(
                color: accent,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStats(
    Color accent,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(
          _formatCount(_user?.followersCount ?? 0),
          'FOLLOWERS',
          textColor,
          subColor,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  FollowersScreen(uid: _user?.uid ?? '', initialTab: 0),
            ),
          ),
        ),
        _buildStatItem(
          _formatCount(_user?.followingCount ?? 0),
          'FOLLOWING',
          textColor,
          subColor,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  FollowersScreen(uid: _user?.uid ?? '', initialTab: 1),
            ),
          ),
        ),
        GestureDetector(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
              ),
            ),
            child: Column(
              children: [
                Text(
                  _formatCount(_user?.pointsBalance ?? 0),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'POINTS',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
    Color textColor,
    Color subColor, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: subColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsGrid(
    List<PostModel> posts,
    Color accent,
    bool isDark, {
    bool showActions = false,
  }) {
    if (posts.isEmpty) {
      return _buildEmptyTab(
        'No posts yet',
        Icons.photo_library_outlined,
        isDark ? Colors.white54 : Colors.black54,
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 1.0,
      ),
      itemCount: posts.length,
      itemBuilder: (ctx, i) {
        final post = posts[i];
        final thumb = post.mediaUrls.isNotEmpty ? post.mediaUrls[0] : '';
        return GestureDetector(
          onTap: () async {
            final deleted = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => PostDetailScreen(
                  post: post,
                  creator: _user,
                  isOwn: _isOwn,
                ),
              ),
            );
            if (deleted == true) {
              _posts.removeWhere((p) => p.postId == post.postId);
              setState(() {});
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: thumb.isNotEmpty
                      ? thumb
                      : 'https://picsum.photos/200/300?random=${post.postId.hashCode}',
                  fit: BoxFit.cover,
                  placeholder: (c, u) => Container(
                    color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
                  ),
                ),
                if (post.mediaUrls.length > 1)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(
                      Icons.copy_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReelsGrid(
    List<ReelModel> reels,
    Color accent,
    bool isDark, {
    bool showActions = false,
  }) {
    if (reels.isEmpty) {
      return _buildEmptyTab(
        'No reels yet',
        Icons.video_library_outlined,
        isDark ? Colors.white54 : Colors.black54,
      );
    }

    // Sort: pinned first
    final pinned = _user?.pinnedReelIds ?? [];
    final sorted = [...reels]
      ..sort((a, b) {
        final aPin = pinned.contains(a.reelId) ? 0 : 1;
        final bPin = pinned.contains(b.reelId) ? 0 : 1;
        return aPin.compareTo(bPin);
      });

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 0.75,
      ),
      itemCount: sorted.length,
      itemBuilder: (ctx, i) {
        final reel = sorted[i];
        final isPinned = pinned.contains(reel.reelId);
        return GestureDetector(
          onLongPress: showActions
              ? () => _showReelOptions(reel, isPinned)
              : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: reel.thumbnailUrl.isNotEmpty
                      ? reel.thumbnailUrl
                      : 'https://picsum.photos/200/300?random=${reel.reelId.hashCode}',
                  fit: BoxFit.cover,
                  placeholder: (c, u) => Container(
                    color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withAlpha(150)],
                    ),
                  ),
                ),
                if (isPinned)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Icon(Icons.push_pin, color: accent, size: 16),
                  ),
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _formatCount(reel.viewsCount),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReelOptions(ReelModel reel, bool isPinned) {
    final accent = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(
                isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                color: accent,
              ),
              title: Text(isPinned ? 'Unpin from Profile' : 'Pin to Profile'),
              onTap: () {
                Navigator.pop(ctx);
                _togglePin(reel);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete Reel',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _deleteReel(reel);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTab(String message, IconData icon, Color color) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(message, style: GoogleFonts.inter(color: color, fontSize: 14)),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color bgColor;
  _TabBarDelegate(this.tabBar, this.bgColor);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: bgColor, child: tabBar);
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}

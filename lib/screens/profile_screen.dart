import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/reel_model.dart';
import '../models/post_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/follow_service.dart';
import '../services/achievement_service.dart';
import '../widgets/level_badge.dart';
import '../utils/animations.dart';
import 'edit_profile_screen.dart';
import 'followers_screen.dart';
import 'settings_screen.dart';
import 'post_detail_screen.dart';
import 'chat_screen.dart';
import 'achievements_screen.dart';
import 'boost_reel_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final AuthService _authService = AuthService();
  final FirestoreService _firestore = FirestoreService();
  final FollowService _followService = FollowService();
  late TabController _tabController;
  UserModel? _user;
  List<PostModel> _posts = [];
  List<ReelModel> _reels = [];
  List<ReelModel> _savedReels = [];
  List<PostModel> _savedPosts = [];
  List<ReelModel> _likedReels = [];
  bool _loading = true;
  bool _isFollowing = false;
  bool _isOwn = true;
  List<Map<String, dynamic>> _earnedAchievements = [];

  @override
  bool get wantKeepAlive => true;

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

      // Load saved posts, saved reels & liked reels for own profile in parallel
      if (_isOwn) {
        final savedReelsFuture = _loadSavedReels(myUid).catchError((_) => <ReelModel>[]);
        final savedPostsFuture = _loadSavedPosts(myUid).catchError((_) => <PostModel>[]);
        final likedFuture = _loadLikedReels(myUid).catchError((_) => <ReelModel>[]);
        final results = await Future.wait([savedReelsFuture, savedPostsFuture, likedFuture]);
        _savedReels = results[0] as List<ReelModel>;
        _savedPosts = results[1] as List<PostModel>;
        _likedReels = results[2] as List<ReelModel>;
      }

      // Load achievements for profile display
      _earnedAchievements = await AchievementService().getUserAchievements(
        widget.userId ?? _authService.currentUser?.uid ?? '',
      );
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

  Future<List<PostModel>> _loadSavedPosts(String uid) async {
    final ids = await _firestore.getSavedPostIds(uid);
    final futures = ids.map((id) => _firestore.getPost(id));
    final results = await Future.wait(futures);
    return results.whereType<PostModel>().toList();
  }

  Future<List<ReelModel>> _loadLikedReels(String uid) async {
    final ids = await _firestore.getLikedReelIds(uid);
    final futures = ids.map((id) => _firestore.getReel(id));
    final results = await Future.wait(futures);
    return results.whereType<ReelModel>().toList();
  }

  Future<void> _toggleFollow() async {
    HapticFeedback.lightImpact();
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
      Navigator.push(context, SlideRightRoute(
        page: ChatScreen(chatId: chat.chatId, partner: _user),
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

  void _showProfilePhotoViewer() {
    final url = _user?.profilePicUrl ?? '';
    if (url.isEmpty) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => _ProfilePhotoViewer(
          imageUrl: url,
          username: _user?.username ?? '',
        ),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    if (_loading && _user == null) {
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0D0D0D)
            : const Color(0xFFF8F9FA),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              const ShimmerProfileHeader(),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemCount: 9,
                  itemBuilder: (_, __) => const ShimmerLoading(borderRadius: 8),
                ),
              ),
            ],
          ),
        ),
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
                  // Cover color banner from user's profile (visible to everyone)
                  _buildCoverBanner(accent, isDark, textColor),
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
                  indicatorSize: TabBarIndicatorSize.label,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: accent.withAlpha(25),
                  ),
                  dividerColor: Colors.transparent,
                  labelColor: accent,
                  unselectedLabelColor: subColor,
                  labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  unselectedLabelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                  tabs: [
                    Tab(icon: Icon(Icons.grid_on_rounded, size: 22)),
                    Tab(icon: Icon(Icons.video_library_rounded, size: 22)),
                    Tab(icon: Icon(Icons.bookmark_rounded, size: 22)),
                    Tab(icon: Icon(Icons.favorite_rounded, size: 22)),
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
                        ? _buildSavedTab(accent, isDark, subColor)
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

  Color _hexToColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  Widget _buildCoverBanner(Color accent, bool isDark, Color textColor) {
    final coverColor = _user != null
        ? _hexToColor(_user!.coverColor)
        : accent;
    final coverSecondary = HSLColor.fromColor(coverColor)
        .withHue((HSLColor.fromColor(coverColor).hue + 40) % 360)
        .toColor();

    return SizedBox(
      height: 180,
      child: Stack(
        children: [
          // Gradient cover at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 130,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [coverColor, coverSecondary.withAlpha(180)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isOwn)
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _user?.username ?? '@user',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          shadows: [const Shadow(blurRadius: 6, color: Colors.black26)],
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_isOwn)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: ScaleTap(
                          onTap: () => Navigator.push(
                            context,
                            SlideRightRoute(page: const SettingsScreen()),
                          ),
                          child: const Icon(Icons.settings_outlined, color: Colors.white, size: 24),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Avatar centered at bottom (within bounds, overlapping the banner)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(child: GestureDetector(
              onLongPress: () => _showProfilePhotoViewer(),
              child: _buildAvatar(accent, isDark),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(Color accent, bool isDark) {
    final secondaryColor = HSLColor.fromColor(accent)
        .withHue((HSLColor.fromColor(accent).hue + 60) % 360)
        .toColor();
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, secondaryColor],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(80),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: secondaryColor.withAlpha(40),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
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
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
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
            const SizedBox(width: 6),
            LevelBadge(level: _user?.viewerLevel ?? 'beginner', compact: true),
          ],
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
        // Achievement badges row
        if (_earnedAchievements.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () => Navigator.push(context, SlideRightRoute(page: const AchievementsScreen())),
              child: SizedBox(
                height: 32,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ..._earnedAchievements.take(5).map((a) {
                      return Container(
                        width: 28, height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withAlpha(20),
                        ),
                        child: Icon(_getAchievementIcon(a['icon'] ?? 'star'), size: 14, color: accent),
                      );
                    }),
                    if (_earnedAchievements.length > 5)
                      Container(
                        width: 28, height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withAlpha(20),
                        ),
                        child: Center(
                          child: Text(
                            '+${_earnedAchievements.length - 5}',
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: accent),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  IconData _getAchievementIcon(String name) {
    switch (name) {
      case 'play_arrow': return Icons.play_arrow_rounded;
      case 'visibility': return Icons.visibility_rounded;
      case 'local_fire_department': return Icons.local_fire_department_rounded;
      case 'whatshot': return Icons.whatshot_rounded;
      case 'bolt': return Icons.bolt_rounded;
      case 'favorite': return Icons.favorite_rounded;
      case 'chat_bubble': return Icons.chat_bubble_rounded;
      case 'shopping_bag': return Icons.shopping_bag_rounded;
      case 'trending_up': return Icons.trending_up_rounded;
      case 'star': return Icons.star_rounded;
      case 'diamond': return Icons.diamond_rounded;
      default: return Icons.emoji_events_rounded;
    }
  }

  Widget _buildActionButtons(Color accent, bool isDark, Color textColor) {
    if (_isOwn) {
      return ScaleTap(
        onTap: () async {
          await Navigator.push(
            context,
            SlideRightRoute(page: const EditProfileScreen()),
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
        ScaleTap(
          onTap: _toggleFollow,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: _isFollowing
                  ? null
                  : LinearGradient(colors: [accent, accent.withAlpha(200)]),
              border: _isFollowing ? Border.all(color: accent, width: 1.5) : null,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _isFollowing ? 'Following' : 'Follow',
                key: ValueKey(_isFollowing),
                style: GoogleFonts.inter(
                  color: _isFollowing ? accent : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ScaleTap(
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
    final cardColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              _formatCount(_user?.followersCount ?? 0),
              'Followers',
              cardColor, textColor, subColor,
              onTap: () => Navigator.push(
                context,
                SlideRightRoute(
                  page: FollowersScreen(uid: _user?.uid ?? '', initialTab: 0),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              _formatCount(_user?.followingCount ?? 0),
              'Following',
              cardColor, textColor, subColor,
              onTap: () => Navigator.push(
                context,
                SlideRightRoute(
                  page: FollowersScreen(uid: _user?.uid ?? '', initialTab: 1),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withAlpha(40),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    _formatCount(_user?.pointsBalance ?? 0),
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Points',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    Color cardColor,
    Color textColor,
    Color subColor, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: textColor.withAlpha(10),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: subColor,
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
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
              FadeScaleRoute(
                page: PostDetailScreen(
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
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: thumb.isNotEmpty
                      ? thumb
                      : 'https://picsum.photos/200/300?random=${post.postId.hashCode}',
                  fit: BoxFit.cover,
                  placeholder: (c, u) => Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (post.mediaUrls.length > 1)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.copy_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
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
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
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
            borderRadius: BorderRadius.circular(12),
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

  Widget _buildSavedTab(Color accent, bool isDark, Color subColor) {
    if (_savedPosts.isEmpty && _savedReels.isEmpty) {
      return _buildEmptyTab(
        'No saved items yet',
        Icons.bookmark_outline,
        subColor,
      );
    }

    final totalCount = _savedPosts.length + _savedReels.length;
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: totalCount,
      itemBuilder: (ctx, i) {
        // Posts first, then reels
        if (i < _savedPosts.length) {
          final post = _savedPosts[i];
          final thumb = post.mediaUrls.isNotEmpty ? post.mediaUrls[0] : '';
          return GestureDetector(
            onTap: () async {
              final deleted = await Navigator.push<bool>(
                context,
                FadeScaleRoute(
                  page: PostDetailScreen(
                    post: post,
                    creator: null,
                    isOwn: false,
                  ),
                ),
              );
              if (deleted == true) {
                _savedPosts.removeWhere((p) => p.postId == post.postId);
                setState(() {});
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
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
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.photo, color: Colors.white, size: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Reel items
        final reelIndex = i - _savedPosts.length;
        final reel = _savedReels[reelIndex];
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
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
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(100),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.videocam, color: Colors.white, size: 12),
                ),
              ),
              Positioned(
                bottom: 6,
                left: 6,
                child: Row(
                  children: [
                    const Icon(Icons.play_arrow, color: Colors.white, size: 14),
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
              leading: Icon(Icons.rocket_launch_rounded, color: accent),
              title: const Text('Boost Reel'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  SlideRightRoute(page: BoostReelScreen(reelId: reel.reelId)),
                );
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

class _ProfilePhotoViewer extends StatelessWidget {
  final String imageUrl;
  final String username;

  const _ProfilePhotoViewer({
    required this.imageUrl,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Center(
              child: Hero(
                tag: 'profile_photo_$imageUrl',
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(100),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (username.isNotEmpty)
                        Text(
                          username,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
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

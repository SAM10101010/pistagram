import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../models/reel_model.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../models/story_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'explore_screen.dart';
import 'notifications_screen.dart';
import 'messages_screen.dart';
import 'comments_screen.dart';
import 'profile_screen.dart';
import 'story_viewer_screen.dart';
import 'upload_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();

  int _selectedTab = 0;
  List<ReelModel> _forYouReels = [];
  List<ReelModel> _followingReels = [];
  List<PostModel> _forYouPosts = [];
  List<PostModel> _followingPosts = [];
  List<UserModel> _followingUsers = [];
  Map<String, UserModel> _userCache = {};
  final Set<String> _likedReelIds = {};
  final Set<String> _savedReelIds = {};
  final Set<String> _likedPostIds = {};
  // Stories
  List<StoryModel> _ownStories = [];
  Map<String, List<StoryModel>> _userStories = {}; // uid -> stories
  List<String> _usersWithStories = []; // uids that have active stories
  // Track double-tap like animation
  String? _doubleTapId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    try {
      final uid = _auth.currentUser?.uid ?? '';

      // Cache own user profile
      if (!_userCache.containsKey(uid)) {
        final ownUser = await _firestore.getUser(uid);
        if (ownUser != null) _userCache[uid] = ownUser;
      }

      // Load data in parallel where possible
      final results = await Future.wait([
        _firestore.getPublicReels(limit: 30),
        _firestore.getPublicPosts(limit: 30),
        _firestore.getFollowingUids(uid),
      ]);

      final publicReels = results[0] as List<ReelModel>;
      final publicPosts = results[1] as List<PostModel>;
      final followingUids = results[2] as List<String>;

      // Filter out posts/reels from private accounts
      final creatorUids = <String>{};
      for (final r in publicReels) creatorUids.add(r.creatorUid);
      for (final p in publicPosts) creatorUids.add(p.creatorUid);

      // Batch fetch all creators for privacy check + cache
      await Future.wait(creatorUids.map((cuid) async {
        if (!_userCache.containsKey(cuid)) {
          final u = await _firestore.getUser(cuid);
          if (u != null) _userCache[cuid] = u;
        }
      }));

      // Filter out content from private accounts (unless user follows them)
      final followingSet = followingUids.toSet();
      _forYouReels = publicReels.where((r) {
        final creator = _userCache[r.creatorUid];
        if (creator == null) return false;
        if (creator.accountType == 'private' && !followingSet.contains(r.creatorUid)) return false;
        return true;
      }).toList();
      _forYouPosts = publicPosts.where((p) {
        final creator = _userCache[p.creatorUid];
        if (creator == null) return false;
        if (creator.accountType == 'private' && !followingSet.contains(p.creatorUid)) return false;
        return true;
      }).toList();

      // Load following content + users in parallel
      if (followingUids.isNotEmpty) {
        final followResults = await Future.wait([
          _firestore.getFeedReels(followingUids, limit: 30),
          _firestore.getFeedPosts(followingUids, limit: 30),
        ]);
        _followingReels = followResults[0] as List<ReelModel>;
        _followingPosts = followResults[1] as List<PostModel>;

        // Cache following creators
        final followCreatorUids = <String>{};
        for (final r in _followingReels) followCreatorUids.add(r.creatorUid);
        for (final p in _followingPosts) followCreatorUids.add(p.creatorUid);
        await Future.wait(followCreatorUids.map((cuid) async {
          if (!_userCache.containsKey(cuid)) {
            final u = await _firestore.getUser(cuid);
            if (u != null) _userCache[cuid] = u;
          }
        }));
      }

      // Load following users for stories row (parallel)
      final storyUserFutures = followingUids.take(20).map((fuid) async {
        if (_userCache.containsKey(fuid)) return _userCache[fuid];
        final u = await _firestore.getUser(fuid);
        if (u != null) _userCache[fuid] = u;
        return u;
      });
      final storyUsers = await Future.wait(storyUserFutures);
      _followingUsers = storyUsers.whereType<UserModel>().toList();

      // Load stories: own + following
      final storyResults = await Future.wait([
        _firestore.getActiveStories(uid),
        followingUids.isNotEmpty
            ? _firestore.getFollowingStories(followingUids)
            : Future.value(<StoryModel>[]),
      ]);
      _ownStories = storyResults[0] as List<StoryModel>;
      final followingStories = storyResults[1] as List<StoryModel>;

      // Group following stories by creator
      _userStories.clear();
      _usersWithStories.clear();
      for (final story in followingStories) {
        _userStories.putIfAbsent(story.creatorUid, () => []).add(story);
      }
      // Sort stories by creation time (newest first)
      for (final stories in _userStories.values) {
        stories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      _usersWithStories = _userStories.keys.toList();

      // Cache users with stories
      for (final suid in _usersWithStories) {
        if (!_userCache.containsKey(suid)) {
          final u = await _firestore.getUser(suid);
          if (u != null) _userCache[suid] = u;
        }
      }

      // Batch check likes/saves in parallel
      final allReels = [..._forYouReels, ..._followingReels];
      final allPosts = [..._forYouPosts, ..._followingPosts];

      final likeCheckFutures = <Future>[];
      for (final reel in allReels) {
        likeCheckFutures.add(_firestore.hasLikedReel(uid, reel.reelId).then((liked) {
          if (liked) _likedReelIds.add(reel.reelId);
        }));
        likeCheckFutures.add(_firestore.hasSavedReel(uid, reel.reelId).then((saved) {
          if (saved) _savedReelIds.add(reel.reelId);
        }));
      }
      for (final post in allPosts) {
        likeCheckFutures.add(_firestore.hasLikedPost(uid, post.postId).then((liked) {
          if (liked) _likedPostIds.add(post.postId);
        }));
      }
      await Future.wait(likeCheckFutures);
    } catch (e) {
      debugPrint('Feed load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleLike(ReelModel reel) async {
    final uid = _auth.currentUser?.uid ?? '';
    if (_likedReelIds.contains(reel.reelId)) {
      await _firestore.unlikeReel(uid, reel.reelId);
      _likedReelIds.remove(reel.reelId);
    } else {
      await _firestore.likeReel(uid, reel.reelId);
      _likedReelIds.add(reel.reelId);
    }
    setState(() {});
  }

  Future<void> _toggleSave(ReelModel reel) async {
    final uid = _auth.currentUser?.uid ?? '';
    if (_savedReelIds.contains(reel.reelId)) {
      await _firestore.unsaveReel(uid, reel.reelId);
      _savedReelIds.remove(reel.reelId);
    } else {
      await _firestore.saveReel(uid, reel.reelId);
      _savedReelIds.add(reel.reelId);
    }
    setState(() {});
  }

  Future<void> _toggleLikePost(PostModel post) async {
    final uid = _auth.currentUser?.uid ?? '';
    if (_likedPostIds.contains(post.postId)) {
      await _firestore.unlikePost(uid, post.postId);
      _likedPostIds.remove(post.postId);
    } else {
      await _firestore.likePost(uid, post.postId);
      _likedPostIds.add(post.postId);
    }
    setState(() {});
  }

  void _onDoubleTapLikeReel(ReelModel reel) {
    if (!_likedReelIds.contains(reel.reelId)) {
      _toggleLike(reel);
    }
    setState(() => _doubleTapId = reel.reelId);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _doubleTapId = null);
    });
  }

  void _onDoubleTapLikePost(PostModel post) {
    if (!_likedPostIds.contains(post.postId)) {
      _toggleLikePost(post);
    }
    setState(() => _doubleTapId = post.postId);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _doubleTapId = null);
    });
  }

  void _shareContent(String type, String id, String caption) {
    final text = caption.isNotEmpty
        ? 'Check out this $type on Pistagram: "$caption"'
        : 'Check out this $type on Pistagram!';
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(accent, isDark, textColor),
            _buildTabBar(accent, isDark, textColor),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: accent))
                  : RefreshIndicator(
                      color: accent,
                      onRefresh: () async {
                        setState(() => _loading = true);
                        _forYouReels.clear();
                        _followingReels.clear();
                        _forYouPosts.clear();
                        _followingPosts.clear();
                        _followingUsers.clear();
                        _userCache.clear();
                        _likedReelIds.clear();
                        _savedReelIds.clear();
                        _likedPostIds.clear();
                        _ownStories.clear();
                        _userStories.clear();
                        _usersWithStories.clear();
                        await _loadFeed();
                      },
                      child: _buildFeedList(
                        accent,
                        isDark,
                        textColor,
                        subColor,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedList(
    Color accent,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    List<Object> items;
    bool showFollowBanner = false;

    if (_selectedTab == 0) {
      final merged = [..._forYouReels, ..._forYouPosts];
      merged.sort((a, b) {
        final da = a is ReelModel ? a.createdAt : (a as PostModel).createdAt;
        final db = b is ReelModel ? b.createdAt : (b as PostModel).createdAt;
        return db.compareTo(da);
      });
      items = merged;
    } else {
      final hasContent =
          _followingReels.isNotEmpty || _followingPosts.isNotEmpty;
      if (!hasContent) {
        final merged = [..._forYouReels, ..._forYouPosts];
        merged.sort((a, b) {
          final da = a is ReelModel ? a.createdAt : (a as PostModel).createdAt;
          final db = b is ReelModel ? b.createdAt : (b as PostModel).createdAt;
          return db.compareTo(da);
        });
        items = merged;
        showFollowBanner = true;
      } else {
        final merged = [..._followingReels, ..._followingPosts];
        merged.sort((a, b) {
          final da = a is ReelModel ? a.createdAt : (a as PostModel).createdAt;
          final db = b is ReelModel ? b.createdAt : (b as PostModel).createdAt;
          return db.compareTo(da);
        });
        items = merged;
      }
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_outlined, size: 64, color: subColor),
            const SizedBox(height: 12),
            Text(
              'No posts yet — be the first!',
              style: GoogleFonts.inter(color: subColor, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length + 1 + (showFollowBanner ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Column(
            children: [
              _buildStoriesRow(accent, isDark),
              const SizedBox(height: 8),
            ],
          );
        }
        if (showFollowBanner && i == 1) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [accent.withAlpha(30), accent.withAlpha(10)],
              ),
              border: Border.all(color: accent.withAlpha(40)),
            ),
            child: Row(
              children: [
                Icon(Icons.person_add_rounded, color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Follow creators to see their content here! Showing public posts for now.',
                    style: GoogleFonts.inter(color: textColor, fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }
        final offset = 1 + (showFollowBanner ? 1 : 0);
        final item = items[i - offset];
        if (item is PostModel) {
          return _buildPhotoCard(item, accent, isDark, textColor, subColor);
        }
        return _buildPostCard(
          item as ReelModel,
          accent,
          isDark,
          textColor,
          subColor,
        );
      },
    );
  }

  Widget _buildTopBar(Color accent, bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 2),
            ),
            child: Icon(Icons.play_arrow_rounded, color: accent, size: 20),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExploreScreen()),
            ),
            icon: Icon(Icons.explore_outlined, color: textColor, size: 26),
          ),
          Stack(
            children: [
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                ),
                icon: Icon(
                  Icons.favorite_border_rounded,
                  color: textColor,
                  size: 26,
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MessagesScreen()),
            ),
            icon: Icon(Icons.send_outlined, color: textColor, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(Color accent, bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildTab('For You', 0, accent, isDark, textColor),
          const SizedBox(width: 24),
          _buildTab('Following', 1, accent, isDark, textColor),
        ],
      ),
    );
  }

  Widget _buildTab(
    String label,
    int index,
    Color accent,
    bool isDark,
    Color textColor,
  ) {
    final isActive = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive
                  ? textColor
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 2.5,
            width: 50,
            decoration: BoxDecoration(
              color: isActive ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoriesRow(Color accent, bool isDark) {
    final uid = _auth.currentUser?.uid ?? '';
    final hasOwnStory = _ownStories.isNotEmpty;

    // Build ordered list: users with stories first, then others
    final storyUsersList = <UserModel>[];
    final nonStoryUsers = <UserModel>[];
    for (final u in _followingUsers) {
      if (_usersWithStories.contains(u.uid)) {
        storyUsersList.add(u);
      } else {
        nonStoryUsers.add(u);
      }
    }
    // Also add users with stories that aren't in _followingUsers
    for (final suid in _usersWithStories) {
      if (!storyUsersList.any((u) => u.uid == suid) && _userCache.containsKey(suid)) {
        storyUsersList.add(_userCache[suid]!);
      }
    }
    final orderedUsers = [...storyUsersList, ...nonStoryUsers];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: orderedUsers.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            // Own story item
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onTap: () {
                  if (hasOwnStory) {
                    // View own story
                    final ownUser = _userCache[uid];
                    if (ownUser != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StoryViewerScreen(
                            stories: _ownStories,
                            creator: ownUser,
                          ),
                        ),
                      );
                    }
                  } else {
                    // Navigate to upload with story category
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UploadScreen()),
                    );
                  }
                },
                child: Column(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: hasOwnStory
                            ? LinearGradient(colors: [accent, accent.withAlpha(150)])
                            : null,
                        border: hasOwnStory
                            ? null
                            : Border.all(
                                color: isDark ? Colors.white24 : Colors.black12,
                                width: 2,
                              ),
                      ),
                      padding: hasOwnStory ? const EdgeInsets.all(2.5) : null,
                      child: CircleAvatar(
                        backgroundColor: isDark
                            ? const Color(0xFF1A1A2E)
                            : Colors.grey[200],
                        backgroundImage: hasOwnStory && _userCache[uid] != null && _userCache[uid]!.profilePicUrl.isNotEmpty
                            ? CachedNetworkImageProvider(_userCache[uid]!.profilePicUrl)
                            : null,
                        child: hasOwnStory
                            ? null
                            : Icon(Icons.add, color: accent, size: 22),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 62,
                      child: Text(
                        hasOwnStory ? 'Your Story' : 'Add Story',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final user = orderedUsers[i - 1];
          final hasStory = _usersWithStories.contains(user.uid);
          final stories = _userStories[user.uid];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: GestureDetector(
              onTap: () {
                if (hasStory && stories != null && stories.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoryViewerScreen(
                        stories: stories,
                        creator: user,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: user.uid),
                    ),
                  );
                }
              },
              child: Column(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: hasStory
                          ? LinearGradient(colors: [accent, accent.withAlpha(150)])
                          : null,
                      border: hasStory
                          ? null
                          : Border.all(
                              color: isDark ? Colors.white24 : Colors.black12,
                              width: 2,
                            ),
                    ),
                    padding: const EdgeInsets.all(2.5),
                    child: CircleAvatar(
                      backgroundColor: isDark
                          ? const Color(0xFF1A1A2E)
                          : Colors.grey[200],
                      backgroundImage: user.profilePicUrl.isNotEmpty
                          ? CachedNetworkImageProvider(user.profilePicUrl)
                          : null,
                      child: user.profilePicUrl.isEmpty
                          ? Icon(
                              Icons.person,
                              color: isDark ? Colors.white38 : Colors.black26,
                              size: 22,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 62,
                    child: Text(
                      user.username,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildPostCard(
    ReelModel reel,
    Color accent,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    final creator = _userCache[reel.creatorUid];
    final isLiked = _likedReelIds.contains(reel.reelId);
    final isSaved = _savedReelIds.contains(reel.reelId);
    final showHeart = _doubleTapId == reel.reelId;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(userId: reel.creatorUid),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [accent, accent.withAlpha(150)],
                      ),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: CircleAvatar(
                      backgroundImage:
                          creator != null && creator.profilePicUrl.isNotEmpty
                          ? CachedNetworkImageProvider(creator.profilePicUrl)
                          : null,
                      child: creator == null || creator.profilePicUrl.isEmpty
                          ? const Icon(Icons.person, size: 18)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          creator?.username ?? 'unknown',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                        if (reel.caption.isNotEmpty)
                          Text(
                            reel.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: subColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.more_horiz, color: subColor, size: 22),
                ],
              ),
            ),
          ),
          // Post image with double-tap to like
          GestureDetector(
            onDoubleTap: () => _onDoubleTapLikeReel(reel),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: 1.0,
                  child: CachedNetworkImage(
                    imageUrl: reel.thumbnailUrl.isNotEmpty
                        ? reel.thumbnailUrl
                        : 'https://picsum.photos/800/800?random=${reel.reelId.hashCode}',
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(
                      color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(
                          color: accent,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                if (showHeart)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.5, end: 1.0),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.elasticOut,
                    builder: (ctx, value, child) => Transform.scale(
                      scale: value,
                      child: child,
                    ),
                    child: Icon(Icons.favorite, color: accent, size: 80),
                  ),
              ],
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleLike(reel),
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? accent : textColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _showComments(context, reel.reelId, false),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: textColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _shareContent('reel', reel.reelId, reel.caption),
                  child: Icon(Icons.send_outlined, color: textColor, size: 24),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _toggleSave(reel),
                  child: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: isSaved ? accent : textColor,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),
          // Likes count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              '${_formatCount(reel.likesCount)} likes',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          // Caption
          if (reel.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: RichText(
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${creator?.username ?? ''} ',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: textColor,
                      ),
                    ),
                    TextSpan(
                      text: reel.caption,
                      style: GoogleFonts.inter(fontSize: 13, color: textColor),
                    ),
                  ],
                ),
              ),
            ),
          // View comments
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: GestureDetector(
              onTap: () => _showComments(context, reel.reelId, false),
              child: Text(
                'View all ${reel.commentsCount} comments',
                style: GoogleFonts.inter(fontSize: 12, color: subColor),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(
    PostModel post,
    Color accent,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    final creator = _userCache[post.creatorUid];
    final isLiked = _likedPostIds.contains(post.postId);
    final showHeart = _doubleTapId == post.postId;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(userId: post.creatorUid),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [accent, accent.withAlpha(150)],
                      ),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: CircleAvatar(
                      backgroundImage:
                          creator != null && creator.profilePicUrl.isNotEmpty
                          ? CachedNetworkImageProvider(creator.profilePicUrl)
                          : null,
                      child: creator == null || creator.profilePicUrl.isEmpty
                          ? const Icon(Icons.person, size: 18)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          creator?.username ?? 'unknown',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                        if (post.caption.isNotEmpty)
                          Text(
                            post.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: subColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.more_horiz, color: subColor, size: 22),
                ],
              ),
            ),
          ),
          // Media with double-tap to like
          if (post.mediaUrls.isNotEmpty)
            GestureDetector(
              onDoubleTap: () => _onDoubleTapLikePost(post),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  post.mediaUrls.length == 1
                      ? AspectRatio(
                          aspectRatio: 1.0,
                          child: CachedNetworkImage(
                            imageUrl: post.mediaUrls[0],
                            fit: BoxFit.cover,
                            placeholder: (c, u) => Container(
                              color: isDark
                                  ? const Color(0xFF1A1A2E)
                                  : Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: accent,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                        )
                      : AspectRatio(
                          aspectRatio: 1.0,
                          child: PageView.builder(
                            itemCount: post.mediaUrls.length,
                            itemBuilder: (ctx, idx) => CachedNetworkImage(
                              imageUrl: post.mediaUrls[idx],
                              fit: BoxFit.cover,
                              placeholder: (c, u) => Container(
                                color: isDark
                                    ? const Color(0xFF1A1A2E)
                                    : Colors.grey[200],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: accent,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                  if (showHeart)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.5, end: 1.0),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.elasticOut,
                      builder: (ctx, value, child) => Transform.scale(
                        scale: value,
                        child: child,
                      ),
                      child: Icon(Icons.favorite, color: accent, size: 80),
                    ),
                ],
              ),
            ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleLikePost(post),
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? accent : textColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _showComments(context, post.postId, true),
                  child: Icon(Icons.chat_bubble_outline, color: textColor, size: 24),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _shareContent('post', post.postId, post.caption),
                  child: Icon(Icons.send_outlined, color: textColor, size: 24),
                ),
                if (post.mediaUrls.length > 1) ...[
                  const Spacer(),
                  Icon(Icons.circle, color: accent, size: 8),
                ],
              ],
            ),
          ),
          // Likes count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              '${_formatCount(post.likesCount)} likes',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          // Caption
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: RichText(
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${creator?.username ?? ''} ',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: textColor,
                      ),
                    ),
                    TextSpan(
                      text: post.caption,
                      style: GoogleFonts.inter(fontSize: 13, color: textColor),
                    ),
                  ],
                ),
              ),
            ),
          // View comments
          if (post.commentsCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: GestureDetector(
                onTap: () => _showComments(context, post.postId, true),
                child: Text(
                  'View all ${post.commentsCount} comments',
                  style: GoogleFonts.inter(fontSize: 12, color: subColor),
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _showComments(BuildContext context, String contentId, bool isPost) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsScreen(reelId: contentId, isPost: isPost),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

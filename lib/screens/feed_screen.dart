import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../models/reel_model.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../models/story_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/cache_service.dart';
import '../utils/animations.dart';
import '../widgets/rotating_story_ring.dart';
import 'explore_screen.dart';
import 'notifications_screen.dart';
import 'messages_screen.dart';
import 'comments_screen.dart';
import 'profile_screen.dart';
import 'story_viewer_screen.dart';
import 'upload_screen.dart';
import 'post_likes_screen.dart';
import 'reel_likes_screen.dart';
import 'share_post_chat_screen.dart';
import 'share_reel_chat_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _auth = AuthService();
  final _firestore = FirestoreService();

  int _selectedTab = 0;
  List<ReelModel> _forYouReels = [];
  List<ReelModel> _followingReels = [];
  List<PostModel> _forYouPosts = [];
  List<PostModel> _followingPosts = [];
  List<UserModel> _followingUsers = [];
  final Map<String, UserModel> _userCache = {};
  final Set<String> _likedReelIds = {};
  final Set<String> _savedReelIds = {};
  final Set<String> _likedPostIds = {};
  final Set<String> _savedPostIds = {};
  // Stories
  List<StoryModel> _ownStories = [];
  final Map<String, List<StoryModel>> _userStories = {}; // uid -> stories
  List<String> _usersWithStories = []; // uids that have active stories
  // Track double-tap like animation
  String? _doubleTapId;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    try {
      final uid = _auth.currentUser?.uid ?? '';

      // Restore cached liked/saved IDs for instant display
      final cache = CacheService.instance;
      final cachedLikedPosts = cache.getData<List>('likedPostIds_$uid');
      if (cachedLikedPosts != null)
        _likedPostIds.addAll(cachedLikedPosts.cast<String>());
      final cachedSavedPosts = cache.getData<List>('savedPostIds_$uid');
      if (cachedSavedPosts != null)
        _savedPostIds.addAll(cachedSavedPosts.cast<String>());
      final cachedLikedReels = cache.getData<List>('likedReelIds_$uid');
      if (cachedLikedReels != null)
        _likedReelIds.addAll(cachedLikedReels.cast<String>());
      final cachedSavedReels = cache.getData<List>('savedReelIds_$uid');
      if (cachedSavedReels != null)
        _savedReelIds.addAll(cachedSavedReels.cast<String>());

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
      for (final r in publicReels) {
        creatorUids.add(r.creatorUid);
      }
      for (final p in publicPosts) {
        creatorUids.add(p.creatorUid);
      }

      // Batch fetch all creators for privacy check + cache
      await Future.wait(
        creatorUids.map((cuid) async {
          if (!_userCache.containsKey(cuid)) {
            final u = await _firestore.getUser(cuid);
            if (u != null) _userCache[cuid] = u;
          }
        }),
      );

      // Filter out content from private accounts (unless user follows them)
      final followingSet = followingUids.toSet();
      _forYouReels = publicReels.where((r) {
        final creator = _userCache[r.creatorUid];
        if (creator == null) return false;
        if (creator.accountType == 'private' &&
            !followingSet.contains(r.creatorUid))
          return false;
        return true;
      }).toList();
      _forYouPosts = publicPosts.where((p) {
        final creator = _userCache[p.creatorUid];
        if (creator == null) return false;
        if (creator.accountType == 'private' &&
            !followingSet.contains(p.creatorUid))
          return false;
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
        for (final r in _followingReels) {
          followCreatorUids.add(r.creatorUid);
        }
        for (final p in _followingPosts) {
          followCreatorUids.add(p.creatorUid);
        }
        await Future.wait(
          followCreatorUids.map((cuid) async {
            if (!_userCache.containsKey(cuid)) {
              final u = await _firestore.getUser(cuid);
              if (u != null) _userCache[cuid] = u;
            }
          }),
        );
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
            ? _firestore.getFollowingStories(followingUids, currentUid: uid)
            : Future.value(<StoryModel>[]),
      ]);
      _ownStories = storyResults[0];
      final followingStories = storyResults[1];

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
        likeCheckFutures.add(
          _firestore.hasLikedReel(uid, reel.reelId).then((liked) {
            if (liked) _likedReelIds.add(reel.reelId);
          }),
        );
        likeCheckFutures.add(
          _firestore.hasSavedReel(uid, reel.reelId).then((saved) {
            if (saved) _savedReelIds.add(reel.reelId);
          }),
        );
      }
      for (final post in allPosts) {
        likeCheckFutures.add(
          _firestore.hasLikedPost(uid, post.postId).then((liked) {
            if (liked) _likedPostIds.add(post.postId);
          }),
        );
        likeCheckFutures.add(
          _firestore.hasSavedPost(uid, post.postId).then((saved) {
            if (saved) _savedPostIds.add(post.postId);
          }),
        );
      }
      await Future.wait(likeCheckFutures);

      // Persist liked/saved IDs to cache
      cache.setData('likedPostIds_$uid', _likedPostIds.toList());
      cache.setData('savedPostIds_$uid', _savedPostIds.toList());
      cache.setData('likedReelIds_$uid', _likedReelIds.toList());
      cache.setData('savedReelIds_$uid', _savedReelIds.toList());
    } catch (e) {
      debugPrint('Feed load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleLike(ReelModel reel) async {
    HapticFeedback.lightImpact();
    final uid = _auth.currentUser?.uid ?? '';
    if (_likedReelIds.contains(reel.reelId)) {
      await _firestore.unlikeReel(uid, reel.reelId);
      _likedReelIds.remove(reel.reelId);
    } else {
      await _firestore.likeReel(uid, reel.reelId, creatorUid: reel.creatorUid);
      _likedReelIds.add(reel.reelId);
    }
    CacheService.instance.setData('likedReelIds_$uid', _likedReelIds.toList());
    setState(() {});
  }

  Future<void> _toggleSave(ReelModel reel) async {
    HapticFeedback.lightImpact();
    final uid = _auth.currentUser?.uid ?? '';
    if (_savedReelIds.contains(reel.reelId)) {
      await _firestore.unsaveReel(uid, reel.reelId);
      _savedReelIds.remove(reel.reelId);
    } else {
      await _firestore.saveReel(uid, reel.reelId);
      _savedReelIds.add(reel.reelId);
    }
    CacheService.instance.setData('savedReelIds_$uid', _savedReelIds.toList());
    setState(() {});
  }

  Future<void> _toggleLikePost(PostModel post) async {
    HapticFeedback.lightImpact();
    final uid = _auth.currentUser?.uid ?? '';
    if (_likedPostIds.contains(post.postId)) {
      await _firestore.unlikePost(uid, post.postId);
      _likedPostIds.remove(post.postId);
    } else {
      await _firestore.likePost(uid, post.postId, creatorUid: post.creatorUid);
      _likedPostIds.add(post.postId);
    }
    CacheService.instance.setData('likedPostIds_$uid', _likedPostIds.toList());
    setState(() {});
  }

  Future<void> _toggleSavePost(PostModel post) async {
    final uid = _auth.currentUser?.uid ?? '';
    final wasSaved = _savedPostIds.contains(post.postId);
    // Optimistic update
    if (wasSaved) {
      _savedPostIds.remove(post.postId);
    } else {
      _savedPostIds.add(post.postId);
    }
    CacheService.instance.setData('savedPostIds_$uid', _savedPostIds.toList());
    setState(() {});
    try {
      if (wasSaved) {
        await _firestore.unsavePost(uid, post.postId);
      } else {
        await _firestore.savePost(uid, post.postId);
      }
    } catch (e) {
      // Rollback on failure
      if (wasSaved) {
        _savedPostIds.add(post.postId);
      } else {
        _savedPostIds.remove(post.postId);
      }
      CacheService.instance.setData(
        'savedPostIds_$uid',
        _savedPostIds.toList(),
      );
      if (mounted) setState(() {});
    }
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
    super.build(context);
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
                  ? _buildShimmerLoading(isDark)
                  : GestureDetector(
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity == null) return;
                        if (details.primaryVelocity! < -300 &&
                            _selectedTab == 0) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTab = 1);
                        } else if (details.primaryVelocity! > 300 &&
                            _selectedTab == 1) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTab = 0);
                        }
                      },
                      child: RefreshIndicator(
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
                          _savedPostIds.clear();
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
        final itemIndex = i - offset;
        if (item is PostModel) {
          return AnimatedListItem(
            index: itemIndex,
            child: _buildPhotoCard(item, accent, isDark, textColor, subColor),
          );
        }
        return AnimatedListItem(
          index: itemIndex,
          child: _buildPostCard(
            item as ReelModel,
            accent,
            isDark,
            textColor,
            subColor,
          ),
        );
      },
    );
  }

  Widget _buildTopBar(Color accent, bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withAlpha(8)
                : Colors.black.withAlpha(8),
          ),
        ),
      ),
      child: Row(
        children: [
          // App logo
          ClipOval(
            child: Image.asset(
              'assets/logo.png',
              width: 38,
              height: 38,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Pistagram',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              foreground: Paint()
                ..shader = LinearGradient(
                  colors: [accent, accent.withAlpha(180)],
                ).createShader(const Rect.fromLTWH(0, 0, 150, 30)),
            ),
          ),
          const Spacer(),
          _buildTopBarIcon(Icons.explore_outlined, textColor, () {
            Navigator.push(
              context,
              SlideRightRoute(page: const ExploreScreen()),
            );
          }),
          StreamBuilder<int>(
            stream: _firestore.getUnreadNotificationCount(
              _auth.currentUser?.uid ?? '',
            ),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Stack(
                children: [
                  _buildTopBarIcon(
                    Icons.favorite_border_rounded,
                    textColor,
                    () {
                      Navigator.push(
                        context,
                        SlideRightRoute(page: const NotificationsScreen()),
                      );
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: PulsingDot(color: accent, size: 8),
                    ),
                ],
              );
            },
          ),
          StreamBuilder<int>(
            stream: _firestore.getUnreadChatCount(_auth.currentUser?.uid ?? ''),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Stack(
                children: [
                  _buildTopBarIcon(Icons.send_outlined, textColor, () {
                    Navigator.push(
                      context,
                      SlideRightRoute(page: const MessagesScreen()),
                    );
                  }),
                  if (count > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: PulsingDot(color: accent, size: 8),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarIcon(IconData icon, Color color, VoidCallback onTap) {
    return ScaleTap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: color, size: 26),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: Column(
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: GoogleFonts.inter(
                fontSize: isActive ? 17 : 15,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w400,
                color: isActive
                    ? textColor
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
              child: Text(label),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              height: 3,
              width: isActive ? 50 : 0,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoriesRow(Color accent, bool isDark) {
    final uid = _auth.currentUser?.uid ?? '';
    final hasOwnStory = _ownStories.isNotEmpty;

    // Build list: only users who have active stories
    final storyUsersList = <UserModel>[];
    for (final u in _followingUsers) {
      if (_usersWithStories.contains(u.uid)) {
        storyUsersList.add(u);
      }
    }
    // Also add users with stories that aren't in _followingUsers
    for (final suid in _usersWithStories) {
      if (!storyUsersList.any((u) => u.uid == suid) &&
          _userCache.containsKey(suid)) {
        storyUsersList.add(_userCache[suid]!);
      }
    }
    final orderedUsers = storyUsersList;

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: orderedUsers.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            // Own story item
            final ownUser = _userCache[uid];
            final hasProfilePic =
                ownUser != null && ownUser.profilePicUrl.isNotEmpty;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onTap: () {
                  if (hasOwnStory) {
                    if (ownUser != null) {
                      Navigator.push(
                        context,
                        FadeScaleRoute(
                          page: StoryViewerScreen(
                            stories: _ownStories,
                            creator: ownUser,
                          ),
                        ),
                      );
                    }
                  } else {
                    Navigator.push(
                      context,
                      SlideUpRoute(page: const UploadScreen()),
                    );
                  }
                },
                child: Column(
                  children: [
                    RotatingStoryRing(
                      hasStory: hasOwnStory,
                      size: 62,
                      color: accent,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: isDark
                                ? const Color(0xFF1A1A2E)
                                : Colors.grey[200],
                            backgroundImage:
                                ownUser != null &&
                                    ownUser.profilePicUrl.isNotEmpty
                                ? CachedNetworkImageProvider(
                                    ownUser.profilePicUrl,
                                  )
                                : null,
                            child: !hasProfilePic
                                ? Icon(
                                    Icons.person,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black26,
                                    size: 22,
                                  )
                                : null,
                          ),
                          if (!hasOwnStory)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accent,
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF0D0D0D)
                                        : Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                        ],
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
                    FadeScaleRoute(
                      page: StoryViewerScreen(stories: stories, creator: user),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    SlideRightRoute(page: ProfileScreen(userId: user.uid)),
                  );
                }
              },
              child: Column(
                children: [
                  RotatingStoryRing(
                    hasStory: hasStory,
                    size: 62,
                    color: accent,
                    child: CircleAvatar(
                      radius: 28,
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
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withAlpha(8)
                : Colors.black.withAlpha(8),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                SlideRightRoute(page: ProfileScreen(userId: reel.creatorUid)),
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
          // Post image with double-tap to like + pinch-to-zoom
          GestureDetector(
            onDoubleTap: () => _onDoubleTapLikeReel(reel),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: 1.0,
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 3.0,
                    clipBehavior: Clip.hardEdge,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final imgWidget = CachedNetworkImage(
                          imageUrl: reel.thumbnailUrl.isNotEmpty
                              ? reel.thumbnailUrl
                              : 'https://picsum.photos/800/800?random=${reel.reelId.hashCode}',
                          fit: BoxFit.cover,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
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
                        );
                        final filter = _getFilterMatrix(reel.filter);
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            if (filter != null)
                              ColorFiltered(
                                colorFilter: filter,
                                child: imgWidget,
                              )
                            else
                              imgWidget,
                            if (reel.overlayText.isNotEmpty)
                              Positioned(
                                left: reel.textX * constraints.maxWidth,
                                top: reel.textY * constraints.maxHeight,
                                child: Text(
                                  reel.overlayText,
                                  style: TextStyle(
                                    color: Color(
                                      int.parse(
                                        reel.textColor.replaceFirst(
                                          '#',
                                          '0xFF',
                                        ),
                                      ),
                                    ),
                                    fontSize: 16 * reel.textScale,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ...reel.stickers.map(
                              (s) => Positioned(
                                left:
                                    (s['x'] as num).toDouble() *
                                    constraints.maxWidth,
                                top:
                                    (s['y'] as num).toDouble() *
                                    constraints.maxHeight,
                                child: Text(
                                  s['emoji'] as String? ?? '',
                                  style: TextStyle(
                                    fontSize:
                                        32 *
                                        ((s['scale'] as num?)?.toDouble() ??
                                            1.0),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                if (showHeart)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.5, end: 1.0),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.elasticOut,
                    builder: (ctx, value, child) =>
                        Transform.scale(scale: value, child: child),
                    child: Icon(Icons.favorite, color: accent, size: 80),
                  ),
              ],
            ),
          ),
          // Music indicator for reels
          if (reel.musicName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.music_note, color: subColor, size: 16),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      reel.musicName,
                      style: GoogleFonts.inter(fontSize: 12, color: subColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                ScaleTap(
                  onTap: () => _toggleLike(reel),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      key: ValueKey(isLiked),
                      color: isLiked ? accent : textColor,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ScaleTap(
                  onTap: () => _showComments(
                    context,
                    reel.reelId,
                    false,
                    creatorUid: reel.creatorUid,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: textColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                ScaleTap(
                  onTap: () => Navigator.push(
                    context,
                    SlideRightRoute(
                      page: ShareReelChatScreen(reelId: reel.reelId),
                    ),
                  ),
                  child: Icon(Icons.send_outlined, color: textColor, size: 24),
                ),
                const Spacer(),
                ScaleTap(
                  onTap: () => _toggleSave(reel),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      key: ValueKey(isSaved),
                      color: isSaved ? accent : textColor,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Likes count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: reel.hideLikes
                ? Text(
                    'Liked by others',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  )
                : GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      SlideRightRoute(
                        page: ReelLikesScreen(reelId: reel.reelId),
                      ),
                    ),
                    child: Text(
                      '${_formatCount(reel.likesCount)} likes',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
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
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // View comments
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: GestureDetector(
              onTap: () => _showComments(
                context,
                reel.reelId,
                false,
                creatorUid: reel.creatorUid,
              ),
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
    final isSavedPost = _savedPostIds.contains(post.postId);
    final showHeart = _doubleTapId == post.postId;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withAlpha(8)
                : Colors.black.withAlpha(8),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                SlideRightRoute(page: ProfileScreen(userId: post.creatorUid)),
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
                        if (post.location.isNotEmpty)
                          Text(
                            post.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: subColor,
                            ),
                          )
                        else if (post.caption.isNotEmpty)
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
          // Media with double-tap to like + pinch-to-zoom
          if (post.mediaUrls.isNotEmpty)
            GestureDetector(
              onDoubleTap: () => _onDoubleTapLikePost(post),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  post.mediaUrls.length == 1
                      ? AspectRatio(
                          aspectRatio: 1.0,
                          child: InteractiveViewer(
                            minScale: 1.0,
                            maxScale: 3.0,
                            clipBehavior: Clip.hardEdge,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final imgWidget = CachedNetworkImage(
                                  imageUrl: post.mediaUrls[0],
                                  fit: BoxFit.cover,
                                  width: constraints.maxWidth,
                                  height: constraints.maxHeight,
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
                                );
                                final filter = _getFilterMatrix(post.filter);
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (filter != null)
                                      ColorFiltered(
                                        colorFilter: filter,
                                        child: imgWidget,
                                      )
                                    else
                                      imgWidget,
                                    if (post.overlayText.isNotEmpty)
                                      Positioned(
                                        left: post.textX * constraints.maxWidth,
                                        top: post.textY * constraints.maxHeight,
                                        child: Text(
                                          post.overlayText,
                                          style: TextStyle(
                                            color: Color(
                                              int.parse(
                                                post.textColor.replaceFirst(
                                                  '#',
                                                  '0xFF',
                                                ),
                                              ),
                                            ),
                                            fontSize: 16 * post.textScale,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ...post.stickers.map(
                                      (s) => Positioned(
                                        left:
                                            (s['x'] as num).toDouble() *
                                            constraints.maxWidth,
                                        top:
                                            (s['y'] as num).toDouble() *
                                            constraints.maxHeight,
                                        child: Text(
                                          s['emoji'] as String? ?? '',
                                          style: TextStyle(
                                            fontSize:
                                                32 *
                                                ((s['scale'] as num?)
                                                        ?.toDouble() ??
                                                    1.0),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        )
                      : AspectRatio(
                          aspectRatio: 1.0,
                          child: PageView.builder(
                            itemCount: post.mediaUrls.length,
                            itemBuilder: (ctx, idx) => LayoutBuilder(
                              builder: (context, constraints) {
                                final imgWidget = CachedNetworkImage(
                                  imageUrl: post.mediaUrls[idx],
                                  fit: BoxFit.cover,
                                  width: constraints.maxWidth,
                                  height: constraints.maxHeight,
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
                                );
                                final filter = _getFilterMatrix(post.filter);
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (filter != null)
                                      ColorFiltered(
                                        colorFilter: filter,
                                        child: imgWidget,
                                      )
                                    else
                                      imgWidget,
                                    if (post.overlayText.isNotEmpty)
                                      Positioned(
                                        left: post.textX * constraints.maxWidth,
                                        top: post.textY * constraints.maxHeight,
                                        child: Text(
                                          post.overlayText,
                                          style: TextStyle(
                                            color: Color(
                                              int.parse(
                                                post.textColor.replaceFirst(
                                                  '#',
                                                  '0xFF',
                                                ),
                                              ),
                                            ),
                                            fontSize: 16 * post.textScale,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ...post.stickers.map(
                                      (s) => Positioned(
                                        left:
                                            (s['x'] as num).toDouble() *
                                            constraints.maxWidth,
                                        top:
                                            (s['y'] as num).toDouble() *
                                            constraints.maxHeight,
                                        child: Text(
                                          s['emoji'] as String? ?? '',
                                          style: TextStyle(
                                            fontSize:
                                                32 *
                                                ((s['scale'] as num?)
                                                        ?.toDouble() ??
                                                    1.0),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                  if (showHeart)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.5, end: 1.0),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.elasticOut,
                      builder: (ctx, value, child) =>
                          Transform.scale(scale: value, child: child),
                      child: Icon(Icons.favorite, color: accent, size: 80),
                    ),
                ],
              ),
            ),
          // Music indicator for posts
          if (post.musicName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.music_note, color: subColor, size: 16),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      post.musicName,
                      style: GoogleFonts.inter(fontSize: 12, color: subColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          // Tagged users indicator
          if (post.taggedUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.person_pin_outlined, color: subColor, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${post.taggedUsers.length} ${post.taggedUsers.length == 1 ? 'person' : 'people'} tagged',
                    style: GoogleFonts.inter(fontSize: 12, color: subColor),
                  ),
                ],
              ),
            ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                ScaleTap(
                  onTap: () => _toggleLikePost(post),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      key: ValueKey(isLiked),
                      color: isLiked ? accent : textColor,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ScaleTap(
                  onTap: () => _showComments(context, post.postId, true),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: textColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                ScaleTap(
                  onTap: () => Navigator.push(
                    context,
                    SlideRightRoute(
                      page: SharePostChatScreen(postId: post.postId),
                    ),
                  ),
                  child: Icon(Icons.send_outlined, color: textColor, size: 24),
                ),
                const Spacer(),
                if (post.mediaUrls.length > 1) ...[
                  Icon(Icons.circle, color: accent, size: 8),
                  const SizedBox(width: 16),
                ],
                ScaleTap(
                  onTap: () => _toggleSavePost(post),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      isSavedPost ? Icons.bookmark : Icons.bookmark_border,
                      key: ValueKey(isSavedPost),
                      color: isSavedPost ? accent : textColor,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Likes count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: post.hideLikes
                ? Text(
                    'Liked by others',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  )
                : GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      SlideRightRoute(
                        page: PostLikesScreen(postId: post.postId),
                      ),
                    ),
                    child: Text(
                      '${_formatCount(post.likesCount)} likes',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
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
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // View comments
          if (post.commentsCount > 0 && !post.hideComments)
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

  void _showComments(
    BuildContext context,
    String contentId,
    bool isPost, {
    String? creatorUid,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsScreen(
        reelId: contentId,
        isPost: isPost,
        creatorUid: creatorUid,
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  ColorFilter? _getFilterMatrix(String filter) {
    switch (filter) {
      case 'warm':
        return const ColorFilter.matrix([
          1.2,
          0.1,
          0,
          0,
          10,
          0,
          1.0,
          0,
          0,
          0,
          0,
          0,
          0.8,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'cool':
        return const ColorFilter.matrix([
          0.8,
          0,
          0,
          0,
          0,
          0,
          1.0,
          0.1,
          0,
          10,
          0,
          0,
          1.2,
          0,
          10,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'sepia':
        return const ColorFilter.matrix([
          0.393,
          0.769,
          0.189,
          0,
          0,
          0.349,
          0.686,
          0.168,
          0,
          0,
          0.272,
          0.534,
          0.131,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'grayscale':
        return const ColorFilter.matrix([
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'vibrant':
        return const ColorFilter.matrix([
          1.3,
          0,
          0,
          0,
          0,
          0,
          1.3,
          0,
          0,
          0,
          0,
          0,
          1.3,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'fade':
        return const ColorFilter.matrix([
          1,
          0,
          0,
          0,
          30,
          0,
          1,
          0,
          0,
          30,
          0,
          0,
          1,
          0,
          30,
          0,
          0,
          0,
          0.9,
          0,
        ]);
      case 'noir':
        return const ColorFilter.matrix([
          0.3,
          0.6,
          0.1,
          0,
          -20,
          0.3,
          0.6,
          0.1,
          0,
          -20,
          0.3,
          0.6,
          0.1,
          0,
          -20,
          0,
          0,
          0,
          1,
          0,
        ]);
      default:
        return null;
    }
  }

  Widget _buildShimmerLoading(bool isDark) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Shimmer stories row
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: List.generate(6, (_) => const ShimmerStoryCircle()),
          ),
        ),
        const SizedBox(height: 8),
        // Shimmer post cards
        ...List.generate(
          3,
          (i) => FadeInSlide(delay: i * 100, child: const ShimmerPostCard()),
        ),
      ],
    );
  }
}

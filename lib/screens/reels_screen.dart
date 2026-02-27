import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/reel_model.dart';
import '../models/user_model.dart';
import '../services/points_service.dart';
import '../services/watch_tracker.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/follow_service.dart';
import '../services/streak_service.dart';
import '../services/reaction_reward_service.dart';
import '../services/series_service.dart';
import '../services/campaign_service.dart';
import '../utils/animations.dart';
import '../services/cache_service.dart';
import 'comments_screen.dart';
import 'profile_screen.dart';

class ReelsScreen extends StatefulWidget {
  final ValueNotifier<int>? activeTabNotifier;
  const ReelsScreen({super.key, this.activeTabNotifier});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final PointsService _pointsService = PointsService();
  final AuthService _authService = AuthService();
  final FirestoreService _firestore = FirestoreService();
  final FollowService _followService = FollowService();
  final StreakService _streakService = StreakService();
  final ReactionRewardService _reactionRewardService = ReactionRewardService();
  final SeriesService _seriesService = SeriesService();
  final CampaignService _campaignService = CampaignService();

  int _currentIndex = 0;
  bool _showPointsPopup = false;
  int _earnedPoints = 0;
  int _totalPoints = 0;
  int _selectedTab = 1;

  List<ReelModel> _reels = [];
  final Map<String, UserModel> _creatorCache = {};
  final Set<String> _likedIds = {};
  final Set<String> _savedIds = {};
  Set<String> _followingIds = {};
  Set<String> _completedReels = {};
  final Map<String, String> _seriesCache = {}; // reelId -> series title
  final Map<String, int> _userRatings = {}; // reelId -> user's rating (1-5)
  bool _loading = true;

  List<VideoPlayerController?> _controllers = [];
  List<WatchTracker?> _trackers = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.activeTabNotifier?.addListener(_onTabVisibilityChanged);
    _loadReels();
  }

  void _onTabVisibilityChanged() {
    if (_controllers.isEmpty || _currentIndex >= _controllers.length) return;
    final isVisible = widget.activeTabNotifier?.value == 1;
    if (isVisible) {
      _controllers[_currentIndex]?.play();
    } else {
      _controllers[_currentIndex]?.pause();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controllers.isEmpty || _currentIndex >= _controllers.length) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _controllers[_currentIndex]?.pause();
    } else if (state == AppLifecycleState.resumed) {
      // Only resume if the reels tab is active
      if (widget.activeTabNotifier == null || widget.activeTabNotifier!.value == 1) {
        _controllers[_currentIndex]?.play();
      }
    }
  }

  Future<void> _loadReels() async {
    try {
      final uid = _authService.currentUser?.uid ?? '';

      // Restore cached liked/saved IDs
      final cache = CacheService.instance;
      final cachedLiked = cache.getData<List>('likedReelIds_$uid');
      if (cachedLiked != null) _likedIds.addAll(cachedLiked.cast<String>());
      final cachedSaved = cache.getData<List>('savedReelIds_$uid');
      if (cachedSaved != null) _savedIds.addAll(cachedSaved.cast<String>());

      _reels = await _firestore.getPublicReels(limit: 20);
      _totalPoints = await _pointsService.getPoints();
      _completedReels = await _pointsService.getCompletedReels();

      // Get following IDs for follow button state
      final followingUids = await _firestore.getFollowingUids(uid);
      _followingIds = followingUids.toSet();

      // Pre-cache creators, like/save states
      for (final reel in _reels) {
        if (!_creatorCache.containsKey(reel.creatorUid)) {
          final u = await _firestore.getUser(reel.creatorUid);
          if (u != null) _creatorCache[reel.creatorUid] = u;
        }
        if (await _firestore.hasLikedReel(uid, reel.reelId)) _likedIds.add(reel.reelId);
        if (await _firestore.hasSavedReel(uid, reel.reelId)) _savedIds.add(reel.reelId);
      }

      // Init video controllers
      _controllers = List.filled(_reels.length, null);
      _trackers = List.filled(_reels.length, null);
      if (_reels.isNotEmpty) _initController(0);
      if (_reels.length > 1) _initController(1);

      // Persist liked/saved to cache
      cache.setData('likedReelIds_$uid', _likedIds.toList());
      cache.setData('savedReelIds_$uid', _savedIds.toList());
    } catch (e) {
      debugPrint('Reels load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _initController(int index) async {
    if (index < 0 || index >= _reels.length) return;
    if (_controllers[index] != null) return;

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(_reels[index].videoUrl),
    );
    _controllers[index] = controller;

    try {
      await controller.initialize();
      controller.setLooping(true);

      final reelId = _reels[index].reelId;
      _trackers[index] = WatchTracker(
        controller: controller,
        reelId: reelId,
        onCompleted: _onReelCompleted,
      );

      // Track view
      _firestore.incrementViews(reelId);

      if (index == _currentIndex) controller.play();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing video $index: $e');
    }
  }

  Future<void> _onReelCompleted(String reelId) async {
    if (_completedReels.contains(reelId)) return;

    final points = PointsService.generateRandomPoints();
    await _pointsService.markReelCompleted(reelId);
    final result = await _pointsService.addPoints(points);
    _totalPoints = (result['newTotal'] as int?) ?? 0;
    _completedReels.add(reelId);

    // Update user's points balance in Firestore
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      await _firestore.updatePointsBalance(uid, _totalPoints);

      // Gamification integrations (fire-and-forget)
      _streakService.onReelCompleted(uid).catchError((_) => null);
      _reactionRewardService.onReelWatched(uid, reelId, points).catchError((_) {});
      _seriesService.onReelWatched(uid, reelId).catchError((_) => null);
      _campaignService.onReelWatched(uid).catchError((_) {});
    }

    if (mounted) {
      setState(() {
        _earnedPoints = points;
        _showPointsPopup = true;
      });
      // Auto-dismiss after 1 second
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => _showPointsPopup = false);
      });
    }
  }

  void _onPageChanged(int index) {
    _controllers[_currentIndex]?.pause();
    _currentIndex = index;
    _controllers[index]?.play();

    if (index + 1 < _reels.length) _initController(index + 1);

    for (int i = 0; i < _controllers.length; i++) {
      if ((i - index).abs() > 2 && _controllers[i] != null) {
        _trackers[i]?.dispose();
        _trackers[i] = null;
        _controllers[i]?.dispose();
        _controllers[i] = null;
      }
    }
    setState(() {});
  }

  Future<void> _toggleLike(int index) async {
    HapticFeedback.lightImpact();
    final uid = _authService.currentUser?.uid ?? '';
    final reelId = _reels[index].reelId;
    if (_likedIds.contains(reelId)) {
      await _firestore.unlikeReel(uid, reelId);
      _likedIds.remove(reelId);
    } else {
      await _firestore.likeReel(uid, reelId, creatorUid: _reels[index].creatorUid);
      _likedIds.add(reelId);
      // Reaction reward for liking (fire-and-forget)
      _reactionRewardService.onReelLiked(uid, reelId).catchError((_) => 0);
    }
    CacheService.instance.setData('likedReelIds_$uid', _likedIds.toList());
    setState(() {});
  }

  Future<void> _toggleSave(int index) async {
    HapticFeedback.lightImpact();
    final uid = _authService.currentUser?.uid ?? '';
    final reelId = _reels[index].reelId;
    if (_savedIds.contains(reelId)) {
      await _firestore.unsaveReel(uid, reelId);
      _savedIds.remove(reelId);
    } else {
      await _firestore.saveReel(uid, reelId);
      _savedIds.add(reelId);
    }
    CacheService.instance.setData('savedReelIds_$uid', _savedIds.toList());
    setState(() {});
  }

  Future<void> _toggleFollow(String targetUid) async {
    final uid = _authService.currentUser?.uid ?? '';
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
    WidgetsBinding.instance.removeObserver(this);
    widget.activeTabNotifier?.removeListener(_onTabVisibilityChanged);
    for (final c in _controllers) { c?.dispose(); }
    for (final t in _trackers) { t?.dispose(); }
    _pageController.dispose();
    super.dispose();
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  Future<void> _showRatingDialog(ReelModel reel) async {
    final uid = _authService.currentUser?.uid ?? '';
    int selectedRating = _userRatings[reel.reelId] ?? 0;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Rate this Reel', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return GestureDetector(
                  onTap: () => setDialogState(() => selectedRating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      i < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: const Color(0xFFFFD700),
                      size: 36,
                    ),
                  ),
                );
              }),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
              ElevatedButton(
                onPressed: selectedRating > 0 ? () => Navigator.pop(ctx, selectedRating) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Submit', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          );
        });
      },
    );
    if (result != null && result > 0) {
      await _firestore.rateReel(uid, reel.reelId, result);
      _userRatings[reel.reelId] = result;
      if (mounted) setState(() {});
    }
  }

  String _formatExpiry(DateTime? expiry) {
    if (expiry == null) return '';
    final diff = expiry.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inHours >= 24) return '${diff.inDays}d left';
    if (diff.inHours >= 1) return '${diff.inHours}h left';
    return '${diff.inMinutes}m left';
  }

  ColorFilter? _getFilterMatrix(String filter) {
    switch (filter) {
      case 'warm': return const ColorFilter.matrix([1.2,0.1,0,0,10, 0,1.0,0,0,0, 0,0,0.8,0,0, 0,0,0,1,0]);
      case 'cool': return const ColorFilter.matrix([0.8,0,0,0,0, 0,1.0,0.1,0,10, 0,0,1.2,0,10, 0,0,0,1,0]);
      case 'sepia': return const ColorFilter.matrix([0.393,0.769,0.189,0,0, 0.349,0.686,0.168,0,0, 0.272,0.534,0.131,0,0, 0,0,0,1,0]);
      case 'grayscale': return const ColorFilter.matrix([0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0,0,0,1,0]);
      case 'vibrant': return const ColorFilter.matrix([1.3,0,0,0,0, 0,1.3,0,0,0, 0,0,1.3,0,0, 0,0,0,1,0]);
      case 'fade': return const ColorFilter.matrix([1,0,0,0,30, 0,1,0,0,30, 0,0,1,0,30, 0,0,0,0.9,0]);
      case 'noir': return const ColorFilter.matrix([0.3,0.6,0.1,0,-20, 0.3,0.6,0.1,0,-20, 0.3,0.6,0.1,0,-20, 0,0,0,1,0]);
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final accent = Theme.of(context).colorScheme.primary;
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.grey[900]!, Colors.black],
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 140,
              child: Column(
                children: List.generate(4, (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(15),
                      shape: BoxShape.circle,
                    ),
                  ),
                )),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 120, height: 14, decoration: BoxDecoration(color: Colors.white.withAlpha(15), borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 8),
                  Container(width: 200, height: 12, decoration: BoxDecoration(color: Colors.white.withAlpha(10), borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ),
            Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2)),
          ],
        ),
      );
    }
    if (_reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.video_library_outlined, color: Colors.white54, size: 64),
              const SizedBox(height: 12),
              Text('No reels yet', style: GoogleFonts.inter(color: Colors.white54, fontSize: 16)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _reels.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (ctx, i) => _buildReelPage(i, accent),
          ),
          // Top tabs
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTopTab('Following', 0, accent),
                  const SizedBox(width: 20),
                  _buildTopTab('For You', 1, accent),
                ],
              ),
            ),
          ),
          // Points toast
          if (_showPointsPopup)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(colors: [accent, const Color(0xFFFFD700)]),
                    boxShadow: [BoxShadow(color: accent.withAlpha(128), blurRadius: 16)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎉', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Text(
                        '+$_earnedPoints Points Earned!',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopTab(String text, int index, Color accent) {
    final isActive = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Text(text, style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
        color: isActive ? Colors.white : Colors.white54,
      )),
    );
  }

  Widget _buildReelPage(int index, Color accent) {
    final controller = _controllers[index];
    final reel = _reels[index];
    final creator = _creatorCache[reel.creatorUid];
    final isLiked = _likedIds.contains(reel.reelId);
    final isSaved = _savedIds.contains(reel.reelId);
    final uid = _authService.currentUser?.uid ?? '';
    final isFollowing = _followingIds.contains(reel.creatorUid);
    final isOwn = reel.creatorUid == uid;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video
        GestureDetector(
          onTap: () {
            if (controller?.value.isPlaying == true) {
              controller?.pause();
            } else {
              controller?.play();
            }
            setState(() {});
          },
          child: Builder(
            builder: (context) {
              final filter = _getFilterMatrix(reel.filter);
              Widget content = controller != null && controller.value.isInitialized
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller.value.size.width,
                        height: controller.value.size.height,
                        child: VideoPlayer(controller),
                      ),
                    )
                  : Container(
                      color: Colors.black,
                      child: reel.thumbnailUrl.isNotEmpty
                          ? CachedNetworkImage(imageUrl: reel.thumbnailUrl, fit: BoxFit.cover)
                          : Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2)),
                    );
              if (filter != null) content = ColorFiltered(colorFilter: filter, child: content);
              return content;
            },
          ),
        ),
        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.transparent, Colors.black.withAlpha(180)],
              stops: const [0, 0.5, 1.0],
            ),
          ),
        ),
        // Text and sticker overlays
        LayoutBuilder(
          builder: (context, constraints) {
            final cw = constraints.maxWidth;
            final ch = constraints.maxHeight;
            return Stack(
              children: [
                if (reel.overlayText.isNotEmpty)
                  Positioned(
                    left: reel.textX * cw,
                    top: reel.textY * ch,
                    child: Text(
                      reel.overlayText,
                      style: TextStyle(
                        fontSize: 16 * reel.textScale,
                        color: reel.textColor.isNotEmpty
                            ? Color(int.parse(reel.textColor.replaceFirst('#', '0xFF')))
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
                      ),
                    ),
                  ),
                ...reel.stickers.map((s) => Positioned(
                  left: (s['x'] as double) * cw,
                  top: (s['y'] as double) * ch,
                  child: Text(s['emoji'] as String, style: TextStyle(fontSize: (s['size'] as double))),
                )),
              ],
            );
          },
        ),
        // Bottom info
        Positioned(
          bottom: 80, left: 14, right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badges row (limited, expiry, series, rating)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (reel.isLimited)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.purple.withAlpha(180),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.visibility_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text('Limited ${reel.viewsCount}/${reel.maxViews}',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  if (reel.expiryTime != null && !reel.isExpired)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(180),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(_formatExpiry(reel.expiryTime),
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  if (_seriesCache.containsKey(reel.reelId))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withAlpha(180),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.playlist_play_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(_seriesCache[reel.reelId]!,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  if (reel.averageRating > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withAlpha(180),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text('${reel.averageRating.toStringAsFixed(1)} (${reel.totalRatings})',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
              if (reel.isLimited || reel.expiryTime != null || _seriesCache.containsKey(reel.reelId) || reel.averageRating > 0)
                const SizedBox(height: 8),
              GestureDetector(
                onTap: () => Navigator.push(context, SlideRightRoute(
                  page: ProfileScreen(userId: reel.creatorUid),
                )),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: creator != null && creator.profilePicUrl.isNotEmpty
                          ? CachedNetworkImageProvider(creator.profilePicUrl) : null,
                      child: creator == null || creator.profilePicUrl.isEmpty
                          ? const Icon(Icons.person, size: 18, color: Colors.white54) : null,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(creator?.username ?? 'unknown', style: GoogleFonts.inter(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (!isOwn && !isFollowing) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _toggleFollow(reel.creatorUid),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Follow', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(reel.caption, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
              if (reel.hashtags.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(reel.hashtags.map((h) => '#$h').join(' '),
                  style: GoogleFonts.inter(color: accent, fontSize: 12, fontWeight: FontWeight.w500),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              if (reel.musicName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.music_note, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(reel.musicName, style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // Right action column
        Positioned(
          right: 10, bottom: 100,
          child: Column(
            children: [
              _buildActionBtn(
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                label: reel.hideLikes ? '' : _formatCount(reel.likesCount),
                color: isLiked ? accent : Colors.white,
                onTap: () => _toggleLike(index),
              ),
              const SizedBox(height: 18),
              _buildActionBtn(
                icon: Icons.chat_bubble_outline,
                label: _formatCount(reel.commentsCount),
                color: Colors.white,
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => CommentsScreen(reelId: reel.reelId, creatorUid: reel.creatorUid),
                ),
              ),
              const SizedBox(height: 18),
              _buildActionBtn(
                icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                label: 'Save',
                color: isSaved ? accent : Colors.white,
                onTap: () => _toggleSave(index),
              ),
              const SizedBox(height: 18),
              _buildActionBtn(
                icon: Icons.share_outlined,
                label: 'Share',
                color: Colors.white,
                onTap: () {},
              ),
              const SizedBox(height: 18),
              _buildActionBtn(
                icon: (_userRatings[reel.reelId] ?? 0) > 0 ? Icons.star_rounded : Icons.star_outline_rounded,
                label: 'Rate',
                color: (_userRatings[reel.reelId] ?? 0) > 0 ? const Color(0xFFFFD700) : Colors.white,
                onTap: () => _showRatingDialog(reel),
              ),
            ],
          ),
        ),
        // Play/pause indicator
        if (controller != null && !controller.value.isPlaying)
          const Center(
            child: Icon(Icons.play_arrow_rounded, color: Colors.white54, size: 70),
          ),
      ],
    );
  }

  Widget _buildActionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return ScaleTap(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: Icon(icon, key: ValueKey(icon), color: color, size: 30),
          ),
          const SizedBox(height: 3),
          Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

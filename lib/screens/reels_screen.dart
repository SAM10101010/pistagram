import 'package:flutter/material.dart';
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
import 'comments_screen.dart';
import 'profile_screen.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final PageController _pageController = PageController();
  final PointsService _pointsService = PointsService();
  final AuthService _authService = AuthService();
  final FirestoreService _firestore = FirestoreService();
  final FollowService _followService = FollowService();

  int _currentIndex = 0;
  bool _showPointsPopup = false;
  int _earnedPoints = 0;
  int _totalPoints = 0;
  int _selectedTab = 1;

  List<ReelModel> _reels = [];
  Map<String, UserModel> _creatorCache = {};
  Set<String> _likedIds = {};
  Set<String> _savedIds = {};
  Set<String> _followingIds = {};
  Set<String> _completedReels = {};
  bool _loading = true;

  List<VideoPlayerController?> _controllers = [];
  List<WatchTracker?> _trackers = [];

  @override
  void initState() {
    super.initState();
    _loadReels();
  }

  Future<void> _loadReels() async {
    try {
      final uid = _authService.currentUser?.uid ?? '';
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
    _totalPoints = await _pointsService.addPoints(points);
    _completedReels.add(reelId);

    // Update user's points balance in Firestore
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      await _firestore.updatePointsBalance(uid, _totalPoints);
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
    final uid = _authService.currentUser?.uid ?? '';
    final reelId = _reels[index].reelId;
    if (_likedIds.contains(reelId)) {
      await _firestore.unlikeReel(uid, reelId);
      _likedIds.remove(reelId);
    } else {
      await _firestore.likeReel(uid, reelId);
      _likedIds.add(reelId);
    }
    setState(() {});
  }

  Future<void> _toggleSave(int index) async {
    final uid = _authService.currentUser?.uid ?? '';
    final reelId = _reels[index].reelId;
    if (_savedIds.contains(reelId)) {
      await _firestore.unsaveReel(uid, reelId);
      _savedIds.remove(reelId);
    } else {
      await _firestore.saveReel(uid, reelId);
      _savedIds.add(reelId);
    }
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

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: accent)),
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
          child: controller != null && controller.value.isInitialized
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
        // Bottom info
        Positioned(
          bottom: 80, left: 14, right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProfileScreen(userId: reel.creatorUid),
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
                    Text(creator?.username ?? 'unknown', style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
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
                label: _formatCount(reel.likesCount),
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
                  builder: (_) => CommentsScreen(reelId: reel.reelId),
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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 3),
          Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

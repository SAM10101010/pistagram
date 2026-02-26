import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/story_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<StoryModel> stories;
  final UserModel creator;
  final int initialIndex;
  const StoryViewerScreen({
    super.key,
    required this.stories,
    required this.creator,
    this.initialIndex = 0,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  late int _currentIndex;
  VideoPlayerController? _videoCtrl;
  late AnimationController _progressCtrl;
  bool _isPaused = false;

  static const Duration _imageDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _progressCtrl = AnimationController(vsync: this);
    _loadStory();
  }

  void _loadStory() {
    _videoCtrl?.dispose();
    _videoCtrl = null;
    _progressCtrl.reset();

    final story = widget.stories[_currentIndex];

    // Mark as viewed
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isNotEmpty && !story.viewerUids.contains(uid)) {
      _firestore.markStoryViewed(story.storyId, uid);
    }

    if (story.mediaType == 'video') {
      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(story.mediaUrl))
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {});
          _videoCtrl!.play();
          _progressCtrl.duration = _videoCtrl!.value.duration;
          _progressCtrl.forward();
          _videoCtrl!.addListener(_onVideoProgress);
        });
    } else {
      _progressCtrl.duration = _imageDuration;
      _progressCtrl.forward();
    }

    _progressCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });
  }

  void _onVideoProgress() {
    if (_videoCtrl == null || !_videoCtrl!.value.isInitialized) return;
    if (_videoCtrl!.value.position >= _videoCtrl!.value.duration) {
      _nextStory();
    }
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _progressCtrl.removeStatusListener((_) {});
      _loadStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _progressCtrl.removeStatusListener((_) {});
      _loadStory();
    }
  }

  void _onTapDown(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (details.globalPosition.dx < screenWidth / 3) {
      _prevStory();
    } else if (details.globalPosition.dx > screenWidth * 2 / 3) {
      _nextStory();
    }
  }

  void _onLongPressStart(_) {
    _isPaused = true;
    _progressCtrl.stop();
    _videoCtrl?.pause();
  }

  void _onLongPressEnd(_) {
    _isPaused = false;
    _progressCtrl.forward();
    _videoCtrl?.play();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];
    final creator = widget.creator;
    final uid = _auth.currentUser?.uid ?? '';
    final isOwn = creator.uid == uid;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: _onLongPressEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Story content
            if (story.mediaType == 'video' &&
                _videoCtrl != null &&
                _videoCtrl!.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _videoCtrl!.value.aspectRatio,
                  child: VideoPlayer(_videoCtrl!),
                ),
              )
            else if (story.mediaType == 'image')
              CachedNetworkImage(
                imageUrl: story.mediaUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Text overlay
            if (story.text.isNotEmpty)
              Positioned(
                left: story.textX * MediaQuery.of(context).size.width - 100,
                top: story.textY * MediaQuery.of(context).size.height - 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    story.text,
                    style: GoogleFonts.inter(
                      color: _parseColor(story.textColor),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            // Sticker overlays
            ...story.stickers.map((s) => Positioned(
              left: (s['x'] as double? ?? 0.5) * MediaQuery.of(context).size.width - 20,
              top: (s['y'] as double? ?? 0.5) * MediaQuery.of(context).size.height - 20,
              child: Text(
                s['emoji'] as String? ?? '',
                style: TextStyle(fontSize: (s['size'] as double? ?? 40)),
              ),
            )),

            // Top gradient
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
              ),
            ),

            // Progress bars
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              right: 12,
              child: Row(
                children: List.generate(widget.stories.length, (i) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: SizedBox(
                          height: 3,
                          child: i < _currentIndex
                              ? const LinearProgressIndicator(
                                  value: 1.0,
                                  backgroundColor: Colors.white30,
                                  color: Colors.white,
                                )
                              : i == _currentIndex
                                  ? AnimatedBuilder(
                                      animation: _progressCtrl,
                                      builder: (_, __) => LinearProgressIndicator(
                                        value: _progressCtrl.value,
                                        backgroundColor: Colors.white30,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const LinearProgressIndicator(
                                      value: 0.0,
                                      backgroundColor: Colors.white30,
                                      color: Colors.white,
                                    ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Header: creator info + close
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: creator.profilePicUrl.isNotEmpty
                        ? CachedNetworkImageProvider(creator.profilePicUrl)
                        : null,
                    child: creator.profilePicUrl.isEmpty
                        ? const Icon(Icons.person, size: 18, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    creator.username,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeago.format(story.createdAt),
                    style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  ),
                ],
              ),
            ),

            // Bottom: viewers count (own story) or reply field
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 12,
              left: 16,
              right: 16,
              child: isOwn
                  ? GestureDetector(
                      onTap: () => _showViewers(story),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.visibility_outlined, color: Colors.white70, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            '${story.viewCount} viewer${story.viewCount == 1 ? '' : 's'}',
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white30),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              'Send message',
                              style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showViewers(StoryModel story) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        height: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Viewers (${story.viewCount})',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: story.viewerUids.isEmpty
                  ? Center(child: Text('No viewers yet', style: GoogleFonts.inter(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: story.viewerUids.length,
                      itemBuilder: (ctx, i) => FutureBuilder<UserModel?>(
                        future: _firestore.getUser(story.viewerUids[i]),
                        builder: (ctx, snap) {
                          final viewer = snap.data;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: viewer != null && viewer.profilePicUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(viewer.profilePicUrl) : null,
                              child: viewer == null || viewer.profilePicUrl.isEmpty
                                  ? const Icon(Icons.person, size: 16) : null,
                            ),
                            title: Text(
                              viewer?.username ?? 'Loading...',
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.white;
    }
  }
}

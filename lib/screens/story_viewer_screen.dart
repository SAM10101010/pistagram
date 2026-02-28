import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';
import '../models/story_model.dart';
import '../models/user_model.dart';
import '../models/comment_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/animations.dart';
import 'share_story_chat_screen.dart';

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
  final _uuid = const Uuid();
  late int _currentIndex;
  VideoPlayerController? _videoCtrl;
  late AnimationController _progressCtrl;

  // Interaction state
  bool _isLiked = false;
  final _commentCtrl = TextEditingController();
  final _commentFocusNode = FocusNode();
  bool _isCommenting = false;

  static const Duration _imageDuration = Duration(seconds: 5);

  static const _emojis = [
    '❤️',
    '🔥',
    '👏',
    '😂',
    '😮',
    '😢',
    '😍',
    '🙏',
    '💯',
    '👍',
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _progressCtrl = AnimationController(vsync: this);
    _commentFocusNode.addListener(_onCommentFocusChange);
    _loadStory();
  }

  void _onCommentFocusChange() {
    if (_commentFocusNode.hasFocus) {
      _progressCtrl.stop();
      _videoCtrl?.pause();
      setState(() => _isCommenting = true);
    } else {
      if (_commentCtrl.text.isEmpty) {
        _progressCtrl.forward();
        _videoCtrl?.play();
        setState(() => _isCommenting = false);
      }
    }
  }

  void _loadStory() {
    _videoCtrl?.dispose();
    _videoCtrl = null;
    _progressCtrl.reset();
    _commentCtrl.clear();
    _isCommenting = false;

    final story = widget.stories[_currentIndex];
    final uid = _auth.currentUser?.uid ?? '';

    // Update like state
    _isLiked = story.likedByUids.contains(uid);

    // Mark as viewed
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
    if (_isCommenting) return;
    final screenWidth = MediaQuery.of(context).size.width;
    if (details.globalPosition.dx < screenWidth / 3) {
      _prevStory();
    } else if (details.globalPosition.dx > screenWidth * 2 / 3) {
      _nextStory();
    }
  }

  void _onLongPressStart(_) {
    if (_isCommenting) return;
    _progressCtrl.stop();
    _videoCtrl?.pause();
  }

  void _onLongPressEnd(_) {
    if (_isCommenting) return;
    _progressCtrl.forward();
    _videoCtrl?.play();
  }

  Future<void> _toggleLike() async {
    HapticFeedback.lightImpact();
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    final story = widget.stories[_currentIndex];
    setState(() => _isLiked = !_isLiked);

    if (_isLiked) {
      await _firestore.likeStory(story.storyId, uid);
    } else {
      await _firestore.unlikeStory(story.storyId, uid);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    _commentCtrl.clear();

    final uid = _auth.currentUser?.uid ?? '';
    final story = widget.stories[_currentIndex];

    final comment = CommentModel(
      id: _uuid.v4(),
      reelId: story.storyId,
      uid: uid,
      text: text,
    );
    await _firestore.addStoryComment(story.storyId, comment);

    _commentFocusNode.unfocus();
    setState(() => _isCommenting = false);
    _progressCtrl.forward();
    _videoCtrl?.play();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Comment sent'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _insertEmoji(String emoji) {
    final text = _commentCtrl.text;
    final selection = _commentCtrl.selection;
    final insertAt = selection.start >= 0 ? selection.start : text.length;
    final newText = text.replaceRange(
      insertAt,
      selection.end >= 0 ? selection.end : insertAt,
      emoji,
    );
    _commentCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: insertAt + emoji.length),
    );
  }

  void _openShareScreen() {
    _progressCtrl.stop();
    _videoCtrl?.pause();
    final story = widget.stories[_currentIndex];
    Navigator.push(
      context,
      SlideUpRoute(page: ShareStoryChatScreen(storyId: story.storyId)),
    ).then((_) {
      if (mounted && !_isCommenting) {
        _progressCtrl.forward();
        _videoCtrl?.play();
      }
    });
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _videoCtrl?.dispose();
    _commentCtrl.dispose();
    _commentFocusNode.removeListener(_onCommentFocusChange);
    _commentFocusNode.dispose();
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
      resizeToAvoidBottomInset: true,
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
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 48,
                  ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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
            ...story.stickers.map(
              (s) => Positioned(
                left:
                    (s['x'] as double? ?? 0.5) *
                        MediaQuery.of(context).size.width -
                    20,
                top:
                    (s['y'] as double? ?? 0.5) *
                        MediaQuery.of(context).size.height -
                    20,
                child: Text(
                  s['emoji'] as String? ?? '',
                  style: TextStyle(fontSize: (s['size'] as double? ?? 40)),
                ),
              ),
            ),

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

            // Bottom gradient
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 160,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
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
                        ? const Icon(
                            Icons.person,
                            size: 18,
                            color: Colors.white,
                          )
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
                    style: GoogleFonts.inter(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),

            // Bottom: own story stats or interaction area
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 8,
              left: 12,
              right: 12,
              child: isOwn
                  ? _buildOwnStoryBottom(story)
                  : _buildInteractionBottom(story),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnStoryBottom(StoryModel story) {
    return GestureDetector(
      onTap: () => _showViewers(story),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.visibility_outlined,
            color: Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            '${story.viewCount} viewer${story.viewCount == 1 ? '' : 's'}',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
          ),
          if (story.likesCount > 0) ...[
            const SizedBox(width: 16),
            const Icon(Icons.favorite, color: Colors.redAccent, size: 18),
            const SizedBox(width: 4),
            Text(
              '${story.likesCount}',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInteractionBottom(StoryModel story) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Emoji bar (visible when commenting)
        if (_isCommenting)
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _emojis.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _insertEmoji(_emojis[i]),
                child: Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text(_emojis[i], style: const TextStyle(fontSize: 22)),
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
        // Comment input + like + share
        Row(
          children: [
            // Comment field
            Expanded(
              child: TextField(
                controller: _commentCtrl,
                focusNode: _commentFocusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendComment(),
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Send a comment...',
                  hintStyle: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                  filled: false,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Colors.white30),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Colors.white60),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  suffixIcon: _isCommenting
                      ? IconButton(
                          onPressed: _sendComment,
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Like button
            GestureDetector(
              onTap: _toggleLike,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  key: ValueKey(_isLiked),
                  color: _isLiked ? Colors.redAccent : Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Share button
            GestureDetector(
              onTap: _openShareScreen,
              child: const Icon(
                Icons.send_outlined,
                color: Colors.white,
                size: 26,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showViewers(StoryModel story) {
    _progressCtrl.stop();
    _videoCtrl?.pause();
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Viewers (${story.viewCount})',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: story.viewerUids.isEmpty
                  ? Center(
                      child: Text(
                        'No viewers yet',
                        style: GoogleFonts.inter(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: story.viewerUids.length,
                      itemBuilder: (ctx, i) => FutureBuilder<UserModel?>(
                        future: _firestore.getUser(story.viewerUids[i]),
                        builder: (ctx, snap) {
                          final viewer = snap.data;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage:
                                  viewer != null &&
                                      viewer.profilePicUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(
                                      viewer.profilePicUrl,
                                    )
                                  : null,
                              child:
                                  viewer == null || viewer.profilePicUrl.isEmpty
                                  ? const Icon(Icons.person, size: 16)
                                  : null,
                            ),
                            title: Text(
                              viewer?.username ?? 'Loading...',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      if (mounted && !_isCommenting) {
        _progressCtrl.forward();
        _videoCtrl?.play();
      }
    });
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.white;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/follow_service.dart';
import '../models/reel_model.dart';
import '../models/user_model.dart';
import 'comments_screen.dart';
import 'reel_share_sheet.dart';
import 'profile_screen.dart';

class ReelDetailScreen extends StatefulWidget {
  final String reelId;
  const ReelDetailScreen({super.key, required this.reelId});

  @override
  State<ReelDetailScreen> createState() => _ReelDetailScreenState();
}

class _ReelDetailScreenState extends State<ReelDetailScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  final _followService = FollowService();

  ReelModel? _reel;
  UserModel? _creator;
  VideoPlayerController? _videoController;
  bool _loading = true;
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isFollowing = false;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = _auth.currentUser?.uid ?? '';
      final reel = await _firestore.getReel(widget.reelId);
      if (reel == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final creator = await _firestore.getUser(reel.creatorUid);
      final liked = await _firestore.hasLikedReel(uid, reel.reelId);
      final saved = await _firestore.hasSavedReel(uid, reel.reelId);
      final following = uid != reel.creatorUid ? await _followService.isFollowing(uid, reel.creatorUid) : false;

      final controller = VideoPlayerController.networkUrl(Uri.parse(reel.videoUrl));
      await controller.initialize();
      controller.setLooping(true);
      controller.play();

      if (mounted) {
        setState(() {
          _reel = reel;
          _creator = creator;
          _videoController = controller;
          _isLiked = liked;
          _isSaved = saved;
          _isFollowing = following;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reel detail: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_reel == null) return;
    final uid = _auth.currentUser?.uid ?? '';
    if (_isLiked) {
      await _firestore.unlikeReel(uid, _reel!.reelId);
    } else {
      await _firestore.likeReel(uid, _reel!.reelId);
    }
    if (mounted) setState(() => _isLiked = !_isLiked);
  }

  Future<void> _toggleSave() async {
    if (_reel == null) return;
    final uid = _auth.currentUser?.uid ?? '';
    if (_isSaved) {
      await _firestore.unsaveReel(uid, _reel!.reelId);
    } else {
      await _firestore.saveReel(uid, _reel!.reelId);
    }
    if (mounted) setState(() => _isSaved = !_isSaved);
  }

  Future<void> _toggleFollow() async {
    if (_reel == null) return;
    final uid = _auth.currentUser?.uid ?? '';
    if (_isFollowing) {
      await _followService.unfollowUser(uid, _reel!.creatorUid);
    } else {
      await _followService.followUser(uid, _reel!.creatorUid);
    }
    if (mounted) setState(() => _isFollowing = !_isFollowing);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final currentUid = _auth.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Reel', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: textColor), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : _reel == null
              ? Center(child: Text('Reel not found', style: GoogleFonts.inter(color: subColor)))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Video player
                      GestureDetector(
                        onTap: () {
                          if (_videoController == null) return;
                          if (_isPlaying) {
                            _videoController!.pause();
                          } else {
                            _videoController!.play();
                          }
                          setState(() => _isPlaying = !_isPlaying);
                        },
                        child: AspectRatio(
                          aspectRatio: 9 / 16,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (_videoController != null && _videoController!.value.isInitialized)
                                VideoPlayer(_videoController!)
                              else
                                Container(color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200]),
                              if (!_isPlaying)
                                Container(
                                  decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                                  padding: const EdgeInsets.all(12),
                                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Creator info
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: _reel!.creatorUid))),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundImage: _creator != null && _creator!.profilePicUrl.isNotEmpty ? CachedNetworkImageProvider(_creator!.profilePicUrl) : null,
                                child: _creator == null || _creator!.profilePicUrl.isEmpty ? const Icon(Icons.person, size: 20) : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_creator?.username ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: textColor)),
                            ),
                            if (currentUid != _reel!.creatorUid)
                              SizedBox(
                                height: 34,
                                child: _isFollowing
                                    ? OutlinedButton(
                                        onPressed: _toggleFollow,
                                        style: OutlinedButton.styleFrom(side: BorderSide(color: subColor.withAlpha(80)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                        child: Text('Following', style: GoogleFonts.inter(fontSize: 12, color: subColor)),
                                      )
                                    : ElevatedButton(
                                        onPressed: _toggleFollow,
                                        style: ElevatedButton.styleFrom(backgroundColor: accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                        child: Text('Follow', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                                      ),
                              ),
                          ],
                        ),
                      ),
                      // Action buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            GestureDetector(onTap: _toggleLike, child: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? accent : textColor, size: 26)),
                            const SizedBox(width: 6),
                            Text(_formatCount(_reel!.likesCount + (_isLiked ? 1 : 0)), style: GoogleFonts.inter(fontSize: 13, color: textColor)),
                            const SizedBox(width: 20),
                            GestureDetector(
                              onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => CommentsScreen(reelId: _reel!.reelId)),
                              child: Icon(Icons.chat_bubble_outline, color: textColor, size: 24),
                            ),
                            const SizedBox(width: 6),
                            Text(_formatCount(_reel!.commentsCount), style: GoogleFonts.inter(fontSize: 13, color: textColor)),
                            const SizedBox(width: 20),
                            GestureDetector(onTap: _toggleSave, child: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, color: _isSaved ? accent : textColor, size: 26)),
                            const SizedBox(width: 20),
                            GestureDetector(onTap: () => ReelShareSheet.show(context, _reel!.reelId), child: Icon(Icons.send_outlined, color: textColor, size: 24)),
                          ],
                        ),
                      ),
                      // Stats
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Text('${_formatCount(_reel!.viewsCount)} views', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                      ),
                      // Caption
                      if (_reel!.caption.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(_reel!.caption, style: GoogleFonts.inter(fontSize: 14, color: textColor)),
                        ),
                      // Hashtags
                      if (_reel!.hashtags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _reel!.hashtags.map((tag) => Chip(
                              label: Text('#$tag', style: GoogleFonts.inter(fontSize: 12, color: accent)),
                              backgroundColor: accent.withAlpha(20),
                              side: BorderSide.none,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            )).toList(),
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }
}

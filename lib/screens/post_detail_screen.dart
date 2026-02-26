import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'comments_screen.dart';
import 'profile_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final PostModel post;
  final UserModel? creator;
  final bool isOwn;
  const PostDetailScreen({super.key, required this.post, this.creator, this.isOwn = false});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  bool _isLiked = false;
  int _likesCount = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.post.likesCount;
    _checkLikeStatus();
  }

  Future<void> _checkLikeStatus() async {
    final uid = _auth.currentUser?.uid ?? '';
    final liked = await _firestore.hasLikedPost(uid, widget.post.postId);
    if (mounted) setState(() => _isLiked = liked);
  }

  Future<void> _toggleLike() async {
    final uid = _auth.currentUser?.uid ?? '';
    if (_isLiked) {
      await _firestore.unlikePost(uid, widget.post.postId);
      _likesCount--;
    } else {
      await _firestore.likePost(uid, widget.post.postId);
      _likesCount++;
    }
    _isLiked = !_isLiked;
    setState(() {});
  }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.deletePost(widget.post.postId);
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final post = widget.post;
    final creator = widget.creator;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Post', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
        centerTitle: true,
        actions: [
          if (widget.isOwn)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: textColor),
              onSelected: (v) {
                if (v == 'delete') _deletePost();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'delete', child: Text('Delete Post', style: TextStyle(color: Colors.red))),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Creator header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: GestureDetector(
                onTap: () {
                  if (creator != null) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: creator.uid),
                    ));
                  }
                },
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [accent, accent.withAlpha(150)]),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: CircleAvatar(
                        backgroundImage: creator != null && creator.profilePicUrl.isNotEmpty
                            ? CachedNetworkImageProvider(creator.profilePicUrl) : null,
                        child: creator == null || creator.profilePicUrl.isEmpty
                            ? const Icon(Icons.person, size: 18) : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(creator?.username ?? 'user', style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, fontSize: 15, color: textColor,
                    )),
                    if (post.location.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.location_on, color: subColor, size: 14),
                      Text(post.location, style: GoogleFonts.inter(fontSize: 12, color: subColor)),
                    ],
                  ],
                ),
              ),
            ),

            // Media
            if (post.mediaUrls.isNotEmpty)
              post.mediaUrls.length == 1
                  ? AspectRatio(
                      aspectRatio: 1.0,
                      child: CachedNetworkImage(
                        imageUrl: post.mediaUrls[0],
                        fit: BoxFit.cover,
                        placeholder: (c, u) => Container(
                          color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
                          child: Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2)),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 1.0,
                          child: PageView.builder(
                            itemCount: post.mediaUrls.length,
                            onPageChanged: (p) => setState(() => _currentPage = p),
                            itemBuilder: (ctx, idx) => CachedNetworkImage(
                              imageUrl: post.mediaUrls[idx],
                              fit: BoxFit.cover,
                              placeholder: (c, u) => Container(
                                color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
                                child: Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(post.mediaUrls.length, (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentPage == i ? 8 : 6,
                            height: _currentPage == i ? 8 : 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentPage == i ? accent : subColor,
                            ),
                          )),
                        ),
                      ],
                    ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? accent : textColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => CommentsScreen(reelId: post.postId, isPost: true),
                    ),
                    child: Icon(Icons.chat_bubble_outline, color: textColor, size: 26),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      final text = post.caption.isNotEmpty
                          ? 'Check out this post on Pistagram: "${post.caption}"'
                          : 'Check out this post on Pistagram!';
                      Share.share(text);
                    },
                    child: Icon(Icons.send_outlined, color: textColor, size: 24),
                  ),
                ],
              ),
            ),

            // Likes
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                '$_likesCount likes',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
              ),
            ),

            // Caption
            if (post.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: RichText(
                  text: TextSpan(children: [
                    TextSpan(
                      text: '${creator?.username ?? ''} ',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
                    ),
                    TextSpan(
                      text: post.caption,
                      style: GoogleFonts.inter(fontSize: 14, color: textColor),
                    ),
                  ]),
                ),
              ),

            // Hashtags
            if (post.hashtags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Text(
                  post.hashtags.map((h) => '#$h').join(' '),
                  style: GoogleFonts.inter(fontSize: 13, color: accent, fontWeight: FontWeight.w500),
                ),
              ),

            // View comments
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => CommentsScreen(reelId: post.postId, isPost: true),
                ),
                child: Text(
                  post.commentsCount > 0
                      ? 'View all ${post.commentsCount} comments'
                      : 'Add a comment...',
                  style: GoogleFonts.inter(fontSize: 13, color: subColor),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

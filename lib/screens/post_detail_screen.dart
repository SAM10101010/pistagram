import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/animations.dart';
import 'comments_screen.dart';
import 'profile_screen.dart';
import 'share_post_chat_screen.dart';
import 'post_likes_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final PostModel post;
  final UserModel? creator;
  final bool isOwn;
  const PostDetailScreen({
    super.key,
    required this.post,
    this.creator,
    this.isOwn = false,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  bool _isLiked = false;
  int _likesCount = 0;
  int _currentPage = 0;
  bool _hideLikes = false;
  bool _hideComments = false;
  bool _allowComments = true;
  String _visibility = 'public';

  @override
  void initState() {
    super.initState();
    _likesCount = widget.post.likesCount;
    _hideLikes = widget.post.hideLikes;
    _hideComments = widget.post.hideComments;
    _allowComments = widget.post.allowComments;
    _visibility = widget.post.visibility;
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
      await _firestore.likePost(
        uid,
        widget.post.postId,
        creatorUid: widget.post.creatorUid,
      );
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
      await _firestore.deletePost(widget.post.postId);
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  void _showPostSettingsSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: subColor.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Post Settings',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                secondary: Icon(Icons.favorite_border, color: accent),
                title: Text(
                  'Hide Like Count',
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                value: _hideLikes,
                activeColor: accent,
                onChanged: (v) async {
                  await _firestore.updatePost(
                    widget.post.postId,
                    {'hideLikes': v},
                  );
                  setState(() => _hideLikes = v);
                  setSheetState(() {});
                },
              ),
              SwitchListTile(
                secondary: Icon(Icons.comment_outlined, color: accent),
                title: Text(
                  'Hide Comments',
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                value: _hideComments,
                activeColor: accent,
                onChanged: (v) async {
                  await _firestore.updatePost(
                    widget.post.postId,
                    {'hideComments': v},
                  );
                  setState(() => _hideComments = v);
                  setSheetState(() {});
                },
              ),
              SwitchListTile(
                secondary: Icon(Icons.chat_bubble_outline, color: accent),
                title: Text(
                  'Allow Comments',
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                value: _allowComments,
                activeColor: accent,
                onChanged: (v) async {
                  await _firestore.updatePost(
                    widget.post.postId,
                    {'allowComments': v},
                  );
                  setState(() => _allowComments = v);
                  setSheetState(() {});
                },
              ),
              ListTile(
                leading: Icon(Icons.visibility_outlined, color: accent),
                title: Text(
                  'Change Visibility',
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Currently: $_visibility',
                  style: GoogleFonts.inter(color: subColor, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showVisibilityPicker();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showVisibilityPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            for (final v in ['public', 'followers', 'private'])
              ListTile(
                leading: Icon(
                  v == 'public'
                      ? Icons.public
                      : v == 'followers'
                          ? Icons.people
                          : Icons.lock,
                  color: _visibility == v
                      ? accent
                      : (isDark ? Colors.white38 : Colors.black38),
                ),
                title: Text(
                  v[0].toUpperCase() + v.substring(1),
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontWeight:
                        _visibility == v ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                trailing: _visibility == v
                    ? Icon(Icons.check_circle, color: accent)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _firestore.updatePost(
                    widget.post.postId,
                    {'visibility': v},
                  );
                  setState(() => _visibility = v);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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

  List<Widget> _buildOverlayWidgets(
    PostModel post,
    double width,
    double height,
  ) {
    return [
      if (post.overlayText.isNotEmpty)
        Positioned(
          left: post.textX * width,
          top: post.textY * height,
          child: Text(
            post.overlayText,
            style: TextStyle(
              fontSize: 16 * post.textScale,
              color: post.textColor.isNotEmpty
                  ? Color(int.parse(post.textColor.replaceFirst('#', '0xFF')))
                  : Colors.white,
              fontWeight: FontWeight.bold,
              shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),
        ),
      ...post.stickers.map(
        (s) => Positioned(
          left: (s['x'] as double) * width,
          top: (s['y'] as double) * height,
          child: Text(
            s['emoji'] as String,
            style: TextStyle(fontSize: (s['size'] as double)),
          ),
        ),
      ),
      if (post.musicName.isNotEmpty)
        Positioned(
          bottom: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.music_note, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  post.musicName,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
    ];
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
      backgroundColor: isDark
          ? const Color(0xFF0D0D0D)
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Post',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.isOwn)
            IconButton(
              icon: Icon(Icons.settings_outlined, color: textColor),
              onPressed: _showPostSettingsSheet,
            ),
          if (widget.isOwn)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: textColor),
              onSelected: (v) {
                if (v == 'delete') _deletePost();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete Post',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
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
                    Navigator.push(
                      context,
                      SlideRightRoute(page: ProfileScreen(userId: creator.uid)),
                    );
                  }
                },
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
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
                    Text(
                      creator?.username ?? 'user',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: textColor,
                      ),
                    ),
                    if (post.location.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.location_on, color: subColor, size: 14),
                      Text(
                        post.location,
                        style: GoogleFonts.inter(fontSize: 12, color: subColor),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Tagged users
            if (post.taggedUsers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_pin_outlined, color: accent, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${post.taggedUsers.length} ${post.taggedUsers.length == 1 ? 'person' : 'people'} tagged',
                      style: GoogleFonts.inter(fontSize: 12, color: accent),
                    ),
                  ],
                ),
              ),

            // Media
            if (post.mediaUrls.isNotEmpty)
              post.mediaUrls.length == 1
                  ? AspectRatio(
                      aspectRatio: 1.0,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final cw = constraints.maxWidth;
                          final ch = constraints.maxHeight;
                          final filter = _getFilterMatrix(post.filter);
                          Widget img = CachedNetworkImage(
                            imageUrl: post.mediaUrls[0],
                            fit: BoxFit.cover,
                            width: cw,
                            height: ch,
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
                          if (filter != null)
                            img = ColorFiltered(
                              colorFilter: filter,
                              child: img,
                            );
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              img,
                              ..._buildOverlayWidgets(post, cw, ch),
                            ],
                          );
                        },
                      ),
                    )
                  : Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 1.0,
                          child: PageView.builder(
                            itemCount: post.mediaUrls.length,
                            onPageChanged: (p) =>
                                setState(() => _currentPage = p),
                            itemBuilder: (ctx, idx) => LayoutBuilder(
                              builder: (context, constraints) {
                                final cw = constraints.maxWidth;
                                final ch = constraints.maxHeight;
                                final filter = _getFilterMatrix(post.filter);
                                Widget img = CachedNetworkImage(
                                  imageUrl: post.mediaUrls[idx],
                                  fit: BoxFit.cover,
                                  width: cw,
                                  height: ch,
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
                                if (filter != null)
                                  img = ColorFiltered(
                                    colorFilter: filter,
                                    child: img,
                                  );
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    img,
                                    ..._buildOverlayWidgets(post, cw, ch),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            post.mediaUrls.length,
                            (i) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: _currentPage == i ? 8 : 6,
                              height: _currentPage == i ? 8 : 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentPage == i ? accent : subColor,
                              ),
                            ),
                          ),
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
                    onTap: (_allowComments || widget.isOwn)
                        ? () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => CommentsScreen(
                                reelId: post.postId,
                                isPost: true,
                                creatorUid: post.creatorUid,
                              ),
                            )
                        : null,
                    child: Icon(
                      Icons.chat_bubble_outline,
                      color: (_allowComments || widget.isOwn)
                          ? textColor
                          : subColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      SlideRightRoute(
                        page: SharePostChatScreen(postId: post.postId),
                      ),
                    ),
                    child: Icon(
                      Icons.send_outlined,
                      color: textColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      final text = post.caption.isNotEmpty
                          ? 'Check out this post on Pistagram: "${post.caption}"'
                          : 'Check out this post on Pistagram!';
                      Share.share(text);
                    },
                    child: Icon(
                      Icons.share_outlined,
                      color: textColor,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            // Likes
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: GestureDetector(
                onTap: (!_hideLikes || widget.isOwn)
                    ? () {
                        Navigator.push(
                          context,
                          SlideRightRoute(
                            page: PostLikesScreen(postId: post.postId),
                          ),
                        );
                      }
                    : null,
                child: Text(
                  (_hideLikes && !widget.isOwn)
                      ? 'Likes hidden'
                      : '$_likesCount likes',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${creator?.username ?? ''} ',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                      TextSpan(
                        text: post.caption,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Hashtags
            if (post.hashtags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: Text(
                  post.hashtags.map((h) => '#$h').join(' '),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            // View comments
            if (!_hideComments || widget.isOwn)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: GestureDetector(
                  onTap: (_allowComments || widget.isOwn)
                      ? () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => CommentsScreen(
                              reelId: post.postId,
                              isPost: true,
                              creatorUid: post.creatorUid,
                            ),
                          )
                      : null,
                  child: Text(
                    !_allowComments && !widget.isOwn
                        ? 'Comments are disabled'
                        : post.commentsCount > 0
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

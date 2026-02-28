import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';
import '../models/comment_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/animations.dart';
import 'package:flutter/gestures.dart';
import 'profile_screen.dart';

class CommentsScreen extends StatefulWidget {
  final String reelId;
  final bool isPost;
  final String? creatorUid;
  final bool allowComments;
  const CommentsScreen({
    super.key,
    required this.reelId,
    this.isPost = false,
    this.creatorUid,
    this.allowComments = true,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  final _commentCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final Map<String, UserModel> _userCache = {};

  CommentModel? _replyingTo;
  String? _replyingToUsername;
  String? _replyingToParentId;
  final Set<String> _expandedReplies = {};

  // @ mention state
  List<UserModel> _mentionResults = [];
  bool _showMentions = false;
  Timer? _mentionDebounce;

  @override
  void initState() {
    super.initState();
    _commentCtrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = _commentCtrl.text;
    final cursorPos = _commentCtrl.selection.baseOffset;
    if (cursorPos < 0 || cursorPos > text.length) return;

    final textBeforeCursor = text.substring(0, cursorPos);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');

    if (lastAtIndex >= 0) {
      final isValidPosition =
          lastAtIndex == 0 || textBeforeCursor[lastAtIndex - 1] == ' ';
      if (isValidPosition) {
        final query = textBeforeCursor.substring(lastAtIndex + 1);
        if (!query.contains(' ') && query.isNotEmpty) {
          _mentionDebounce?.cancel();
          _mentionDebounce = Timer(const Duration(milliseconds: 300), () {
            _searchMentionUsers(query);
          });
          return;
        }
      }
    }

    if (_showMentions) {
      setState(() {
        _showMentions = false;
        _mentionResults = [];
      });
    }
  }

  Future<void> _searchMentionUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _showMentions = false;
        _mentionResults = [];
      });
      return;
    }
    final results = await _firestore.searchUsers(query);
    if (mounted) {
      setState(() {
        _mentionResults = results;
        _showMentions = results.isNotEmpty;
      });
    }
  }

  void _insertMention(UserModel user) {
    final text = _commentCtrl.text;
    final cursorPos = _commentCtrl.selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPos);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');
    final textAfterCursor = text.substring(cursorPos);

    final newText =
        '${text.substring(0, lastAtIndex)}@${user.username} $textAfterCursor';
    final newCursorPos = lastAtIndex + user.username.length + 2;

    _commentCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );

    setState(() {
      _showMentions = false;
      _mentionResults = [];
    });
  }

  Future<UserModel?> _getCachedUser(String uid) async {
    if (_userCache.containsKey(uid)) return _userCache[uid];
    final u = await _firestore.getUser(uid);
    if (u != null) _userCache[uid] = u;
    return u;
  }

  Future<void> _postComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final uid = _auth.currentUser?.uid ?? '';

    if (_replyingTo != null) {
      final parentId = _replyingToParentId ?? _replyingTo!.id;

      final reply = CommentModel(
        id: const Uuid().v4(),
        reelId: widget.reelId,
        uid: uid,
        text: text,
        parentId: parentId,
      );
      await _firestore.addReply(
        reply,
        parentCommentUid: _replyingTo!.uid,
        contentCreatorUid: widget.creatorUid,
      );
      setState(() {
        _expandedReplies.add(parentId);
        _replyingTo = null;
        _replyingToUsername = null;
        _replyingToParentId = null;
      });
    } else {
      final comment = CommentModel(
        id: const Uuid().v4(),
        reelId: widget.reelId,
        uid: uid,
        text: text,
      );
      if (widget.isPost) {
        await _firestore.addPostComment(comment, creatorUid: widget.creatorUid);
      } else {
        await _firestore.addComment(comment, creatorUid: widget.creatorUid);
      }
    }
    _commentCtrl.clear();
  }

  Future<void> _deleteComment(CommentModel comment) async {
    if (widget.isPost) {
      await _firestore.deletePostComment(comment.id, comment.reelId);
    } else {
      await _firestore.deleteComment(comment.id, comment.reelId);
    }
  }

  Future<void> _toggleCommentLike(CommentModel comment) async {
    final uid = _auth.currentUser?.uid ?? '';
    if (comment.likedByUids.contains(uid)) {
      await _firestore.unlikeComment(comment.id, uid);
    } else {
      await _firestore.likeComment(
        comment.id,
        uid,
        commentOwnerUid: comment.uid,
        reelId: widget.isPost ? null : widget.reelId,
        postId: widget.isPost ? widget.reelId : null,
      );
    }
  }

  void _startReply(CommentModel comment, String username,
      {String? topLevelParentId}) {
    setState(() {
      _replyingTo = comment;
      _replyingToUsername = username;
      _replyingToParentId = topLevelParentId;
    });
    _commentCtrl.text = '@$username ';
    _commentCtrl.selection =
        TextSelection.collapsed(offset: _commentCtrl.text.length);
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _replyingToUsername = null;
      _replyingToParentId = null;
    });
    _commentCtrl.clear();
  }

  @override
  void dispose() {
    _commentCtrl.removeListener(_onTextChanged);
    _commentCtrl.dispose();
    _focusNode.dispose();
    _mentionDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final uid = _auth.currentUser?.uid ?? '';

    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final containerHeight =
        min(screenHeight * 0.65, screenHeight - keyboardHeight);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        height: containerHeight,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Comments',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
            ),
            Divider(
                height: 1, color: isDark ? Colors.white12 : Colors.black12),

            // Comments list
            Expanded(
              child: StreamBuilder<List<CommentModel>>(
                stream: _firestore.getComments(widget.reelId),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: 5,
                      itemBuilder: (_, __) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            const ShimmerLoading(
                              width: 32,
                              height: 32,
                              isCircle: true,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  ShimmerLoading(
                                    width: 160,
                                    height: 12,
                                    borderRadius: 6,
                                  ),
                                  SizedBox(height: 6),
                                  ShimmerLoading(
                                    width: 80,
                                    height: 10,
                                    borderRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final comments = snap.data ?? [];
                  if (comments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? const Color(0xFF0D0D0D)
                                  : Colors.grey[100],
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              color: subColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No comments yet',
                            style: GoogleFonts.inter(
                              color: subColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Be the first to comment!',
                            style: GoogleFonts.inter(
                              color: subColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: comments.length,
                    itemBuilder: (ctx, i) => _buildCommentTile(
                      comments[i],
                      uid,
                      accent,
                      isDark,
                      textColor,
                      subColor,
                    ),
                  );
                },
              ),
            ),

            // @ Mention suggestions
            if (_showMentions && _mentionResults.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withAlpha(15)
                          : Colors.black.withAlpha(15),
                    ),
                  ),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _mentionResults.length,
                  itemBuilder: (_, i) {
                    final user = _mentionResults[i];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            isDark ? Colors.white12 : Colors.grey[200],
                        backgroundImage: user.profilePicUrl.isNotEmpty
                            ? CachedNetworkImageProvider(user.profilePicUrl)
                            : null,
                        child: user.profilePicUrl.isEmpty
                            ? Icon(Icons.person, size: 14, color: subColor)
                            : null,
                      ),
                      title: Text(
                        user.username,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      subtitle: user.displayName.isNotEmpty
                          ? Text(
                              user.displayName,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: subColor,
                              ),
                            )
                          : null,
                      onTap: () => _insertMention(user),
                    );
                  },
                ),
              ),

            // Emoji suggestions bar
            if (widget.allowComments && !_showMentions)
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D0D0D) : Colors.grey[50],
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withAlpha(10)
                          : Colors.black.withAlpha(10),
                    ),
                  ),
                ),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  children: [
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
                    '🎉',
                    '💀',
                    '👀',
                    '✨',
                  ]
                      .map(
                        (emoji) => GestureDetector(
                          onTap: () {
                            final text = _commentCtrl.text;
                            final selection = _commentCtrl.selection;
                            final newText = text.replaceRange(
                              selection.start >= 0
                                  ? selection.start
                                  : text.length,
                              selection.end >= 0
                                  ? selection.end
                                  : text.length,
                              emoji,
                            );
                            _commentCtrl.value = TextEditingValue(
                              text: newText,
                              selection: TextSelection.collapsed(
                                offset: (selection.start >= 0
                                        ? selection.start
                                        : text.length) +
                                    emoji.length,
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

            // Reply banner
            if (widget.allowComments && _replyingTo != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D0D0D) : Colors.grey[100],
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withAlpha(10)
                          : Colors.black.withAlpha(10),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Replying to ',
                      style: GoogleFonts.inter(color: subColor, fontSize: 13),
                    ),
                    Text(
                      '@${_replyingToUsername ?? 'user'}',
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _cancelReply,
                      child: Icon(Icons.close_rounded,
                          color: subColor, size: 18),
                    ),
                  ],
                ),
              ),

            // Comment input
            if (widget.allowComments)
              Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 8,
                  top: 8,
                  bottom: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D0D0D) : Colors.grey[50],
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withAlpha(15)
                          : Colors.black.withAlpha(15),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        focusNode: _focusNode,
                        style: TextStyle(color: textColor, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: _replyingTo != null
                              ? 'Reply to @${_replyingToUsername ?? 'user'}...'
                              : 'Add a comment...',
                          hintStyle:
                              TextStyle(color: subColor, fontSize: 14),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _postComment,
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent,
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 14,
                  bottom: 14,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D0D0D) : Colors.grey[50],
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withAlpha(15)
                          : Colors.black.withAlpha(15),
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Comments are turned off',
                    style: GoogleFonts.inter(color: subColor, fontSize: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentRichText(
    String commentText,
    String username,
    String uid,
    Color textColor,
    Color accentColor, {
    double fontSize = 13,
  }) {
    final spans = <InlineSpan>[];

    spans.add(TextSpan(
      text: '$username ',
      style: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: fontSize,
        color: textColor,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () => Navigator.push(
              context,
              SlideRightRoute(page: ProfileScreen(userId: uid)),
            ),
    ));

    final mentionRegex = RegExp(r'@(\w+)');
    int lastEnd = 0;
    for (final match in mentionRegex.allMatches(commentText)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: commentText.substring(lastEnd, match.start),
          style: GoogleFonts.inter(fontSize: fontSize, color: textColor),
        ));
      }

      final mentionUsername = match.group(1)!;
      spans.add(TextSpan(
        text: '@$mentionUsername',
        style: GoogleFonts.inter(
          fontSize: fontSize,
          color: accentColor,
          fontWeight: FontWeight.w600,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final users = await _firestore.searchUsers(mentionUsername);
            if (users.isNotEmpty && mounted) {
              Navigator.push(
                context,
                SlideRightRoute(
                    page: ProfileScreen(userId: users.first.uid)),
              );
            }
          },
      ));

      lastEnd = match.end;
    }

    if (lastEnd < commentText.length) {
      spans.add(TextSpan(
        text: commentText.substring(lastEnd),
        style: GoogleFonts.inter(fontSize: fontSize, color: textColor),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildCommentTile(
    CommentModel comment,
    String myUid,
    Color accent,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    final isLiked = comment.likedByUids.contains(myUid);
    final isOwn = comment.uid == myUid;

    return FutureBuilder<UserModel?>(
      future: _getCachedUser(comment.uid),
      builder: (ctx, snap) {
        final user = snap.data;
        final username = user?.username ?? 'user';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main comment
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      SlideRightRoute(
                          page: ProfileScreen(userId: comment.uid)),
                    ),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          isDark ? Colors.white12 : Colors.grey[200],
                      backgroundImage:
                          user != null && user.profilePicUrl.isNotEmpty
                              ? CachedNetworkImageProvider(
                                  user.profilePicUrl)
                              : null,
                      child: user == null || user.profilePicUrl.isEmpty
                          ? Icon(Icons.person, size: 16, color: subColor)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCommentRichText(
                          comment.text,
                          username,
                          comment.uid,
                          textColor,
                          accent,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              timeago.format(comment.createdAt),
                              style: GoogleFonts.inter(
                                  color: subColor, fontSize: 11),
                            ),
                            if (comment.likesCount > 0) ...[
                              const SizedBox(width: 16),
                              Text(
                                '${comment.likesCount} ${comment.likesCount == 1 ? 'like' : 'likes'}',
                                style: GoogleFonts.inter(
                                  color: subColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (widget.allowComments) ...[
                              const SizedBox(width: 16),
                              GestureDetector(
                                onTap: () =>
                                    _startReply(comment, username),
                                child: Text(
                                  'Reply',
                                  style: GoogleFonts.inter(
                                    color: subColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      GestureDetector(
                        onTap: () => _toggleCommentLike(comment),
                        child: Icon(
                          isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: isLiked ? Colors.redAccent : subColor,
                          size: 16,
                        ),
                      ),
                      if (isOwn)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: GestureDetector(
                            onTap: () => _deleteComment(comment),
                            child: Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // View replies button
            if (comment.repliesCount > 0 &&
                !_expandedReplies.contains(comment.id))
              Padding(
                padding: const EdgeInsets.only(left: 58, bottom: 4),
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _expandedReplies.add(comment.id)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 1,
                        color: subColor.withAlpha(80),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'View ${comment.repliesCount} ${comment.repliesCount == 1 ? 'reply' : 'replies'}',
                        style: GoogleFonts.inter(
                          color: subColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Hide replies button
            if (_expandedReplies.contains(comment.id) &&
                comment.repliesCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 58, bottom: 4),
                child: GestureDetector(
                  onTap: () => setState(
                      () => _expandedReplies.remove(comment.id)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 1,
                        color: subColor.withAlpha(80),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Hide replies',
                        style: GoogleFonts.inter(
                          color: subColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Replies list (expanded)
            if (_expandedReplies.contains(comment.id))
              Padding(
                padding: const EdgeInsets.only(left: 42),
                child: StreamBuilder<List<CommentModel>>(
                  stream: _firestore.getReplies(comment.id),
                  builder: (ctx, replySnap) {
                    final replies = replySnap.data ?? [];
                    if (replies.isEmpty) return const SizedBox.shrink();
                    return Column(
                      children: replies
                          .map((reply) => _buildReplyTile(
                                reply,
                                myUid,
                                accent,
                                isDark,
                                textColor,
                                subColor,
                                topLevelCommentId: comment.id,
                              ))
                          .toList(),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildReplyTile(
    CommentModel reply,
    String myUid,
    Color accent,
    bool isDark,
    Color textColor,
    Color subColor, {
    required String topLevelCommentId,
  }) {
    final isLiked = reply.likedByUids.contains(myUid);
    final isOwn = reply.uid == myUid;

    return FutureBuilder<UserModel?>(
      future: _getCachedUser(reply.uid),
      builder: (ctx, snap) {
        final user = snap.data;
        final username = user?.username ?? 'user';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  SlideRightRoute(page: ProfileScreen(userId: reply.uid)),
                ),
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor:
                      isDark ? Colors.white12 : Colors.grey[200],
                  backgroundImage:
                      user != null && user.profilePicUrl.isNotEmpty
                          ? CachedNetworkImageProvider(user.profilePicUrl)
                          : null,
                  child: user == null || user.profilePicUrl.isEmpty
                      ? Icon(Icons.person, size: 12, color: subColor)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCommentRichText(
                      reply.text,
                      username,
                      reply.uid,
                      textColor,
                      accent,
                      fontSize: 12,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          timeago.format(reply.createdAt),
                          style: GoogleFonts.inter(
                              color: subColor, fontSize: 10),
                        ),
                        if (reply.likesCount > 0) ...[
                          const SizedBox(width: 12),
                          Text(
                            '${reply.likesCount} ${reply.likesCount == 1 ? 'like' : 'likes'}',
                            style: GoogleFonts.inter(
                              color: subColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (widget.allowComments) ...[
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _startReply(
                              reply,
                              username,
                              topLevelParentId: topLevelCommentId,
                            ),
                            child: Text(
                              'Reply',
                              style: GoogleFonts.inter(
                                color: subColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  GestureDetector(
                    onTap: () => _toggleCommentLike(reply),
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.redAccent : subColor,
                      size: 14,
                    ),
                  ),
                  if (isOwn)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: GestureDetector(
                        onTap: () => _deleteComment(reply),
                        child: Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

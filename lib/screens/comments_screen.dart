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

class CommentsScreen extends StatefulWidget {
  final String reelId;
  final bool isPost;
  final String? creatorUid;
  const CommentsScreen({super.key, required this.reelId, this.isPost = false, this.creatorUid});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  final _commentCtrl = TextEditingController();
  final Map<String, UserModel> _userCache = {};

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
    _commentCtrl.clear();
  }

  Future<void> _deleteComment(CommentModel comment) async {
    if (widget.isPost) {
      await _firestore.deletePostComment(comment.id, comment.reelId);
    } else {
      await _firestore.deleteComment(comment.id, comment.reelId);
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final uid = _auth.currentUser?.uid ?? '';

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
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
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text('Comments', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: textColor)),
          ),
          Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),

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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(children: [
                        const ShimmerLoading(width: 32, height: 32, isCircle: true),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                          ShimmerLoading(width: 160, height: 12, borderRadius: 6),
                          SizedBox(height: 6),
                          ShimmerLoading(width: 80, height: 10, borderRadius: 6),
                        ])),
                      ]),
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
                          width: 64, height: 64,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? const Color(0xFF0D0D0D) : Colors.grey[100]),
                          child: Icon(Icons.chat_bubble_outline, color: subColor, size: 28),
                        ),
                        const SizedBox(height: 12),
                        Text('No comments yet', style: GoogleFonts.inter(color: subColor, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('Be the first to comment!', style: GoogleFonts.inter(color: subColor, fontSize: 12)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: comments.length,
                  itemBuilder: (ctx, i) => _buildCommentTile(comments[i], uid, accent, isDark, textColor, subColor),
                );
              },
            ),
          ),

          // Comment input
          Container(
            padding: EdgeInsets.only(
              left: 16, right: 8, top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D0D0D) : Colors.grey[50],
              border: Border(top: BorderSide(color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(15))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: subColor, fontSize: 14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _postComment,
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(CommentModel comment, String myUid, Color accent, bool isDark, Color textColor, Color subColor) {
    return FutureBuilder<UserModel?>(
      future: _getCachedUser(comment.uid),
      builder: (ctx, snap) {
        final user = snap.data;
        final isOwn = comment.uid == myUid;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
                backgroundImage: user != null && user.profilePicUrl.isNotEmpty
                    ? CachedNetworkImageProvider(user.profilePicUrl) : null,
                child: user == null || user.profilePicUrl.isEmpty
                    ? Icon(Icons.person, size: 16, color: subColor) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: '${user?.username ?? 'user'} ',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: textColor),
                        ),
                        TextSpan(
                          text: comment.text,
                          style: GoogleFonts.inter(fontSize: 13, color: textColor),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(comment.createdAt),
                      style: GoogleFonts.inter(color: subColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (isOwn)
                IconButton(
                  onPressed: () => _deleteComment(comment),
                  icon: Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                  iconSize: 18,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
        );
      },
    );
  }
}

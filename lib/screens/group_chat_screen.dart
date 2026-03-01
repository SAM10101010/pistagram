import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../models/group_chat_model.dart';
import '../models/group_message_model.dart';
import '../models/user_model.dart';
import '../services/group_chat_service.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';
import '../utils/animations.dart';
import 'group_info_screen.dart';
import 'post_detail_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final GroupChatModel? group;
  const GroupChatScreen({super.key, required this.groupId, this.group});
  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _groupService = GroupChatService();
  final _authService = AuthService();
  final _cloudinary = CloudinaryService();
  final _firestore = FirestoreService();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _picker = ImagePicker();
  final Map<String, UserModel?> _userCache = {};

  bool _showEmojiPanel = false;
  bool _uploading = false;
  String? _editingMessageId;

  static const _emojis = [
    '😀', '😂', '🥹', '😍', '🥰', '😘', '😎', '🤩',
    '😢', '😭', '😤', '🤯', '🥳', '😴', '🤔', '🫡',
    '👍', '👎', '👏', '🙌', '🤝', '💪', '🫶', '✌️',
    '❤️', '🔥', '💯', '⭐', '🎉', '💀', '👀', '✨',
    '🙏', '💕', '😈', '🤡', '💔', '🥺', '😱', '🤮',
  ];

  Future<UserModel?> _getCachedUser(String uid) async {
    if (_userCache.containsKey(uid)) return _userCache[uid];
    final u = await _firestore.getUser(uid);
    _userCache[uid] = u;
    return u;
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();

    if (_editingMessageId != null) {
      await _groupService.editMessage(
        widget.groupId,
        _editingMessageId!,
        text,
      );
      setState(() => _editingMessageId = null);
    } else {
      await _groupService.sendMessage(
        groupId: widget.groupId,
        senderUid: _authService.currentUser?.uid ?? '',
        text: text,
      );
    }
  }

  Future<void> _pickAndSendImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final result = await _cloudinary.uploadFile(
        File(picked.path),
        folder: 'chat_media',
      );
      final url = result['url'] ?? '';
      if (url.isNotEmpty) {
        await _groupService.sendMessage(
          groupId: widget.groupId,
          senderUid: _authService.currentUser?.uid ?? '',
          mediaUrl: url,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send image: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    if (mounted) setState(() => _uploading = false);
  }

  void _startEdit(GroupMessageModel msg) {
    setState(() {
      _editingMessageId = msg.id;
      _msgCtrl.text = msg.text;
      _showEmojiPanel = false;
    });
    _msgCtrl.selection = TextSelection.collapsed(offset: _msgCtrl.text.length);
  }

  void _cancelEdit() {
    setState(() {
      _editingMessageId = null;
      _msgCtrl.clear();
    });
  }

  Future<void> _deleteMessage(GroupMessageModel msg) async {
    final uid = _authService.currentUser?.uid ?? '';
    await _groupService.deleteMessage(widget.groupId, msg.id, uid);
  }

  void _showMessageOptions(GroupMessageModel msg, bool isAdmin) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;
    final uid = _authService.currentUser?.uid ?? '';
    final isOwn = msg.senderUid == uid;

    HapticFeedback.mediumImpact();
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
            if (isOwn && msg.text.isNotEmpty)
              ListTile(
                leading: Icon(Icons.edit_outlined, color: accent),
                title: Text('Edit Message',
                    style: GoogleFonts.inter(
                        color: textColor, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(ctx);
                  _startEdit(msg);
                },
              ),
            if (isOwn || isAdmin)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text('Delete Message',
                    style: GoogleFonts.inter(
                        color: Colors.redAccent, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(msg);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _insertEmoji(String emoji) {
    final text = _msgCtrl.text;
    final selection = _msgCtrl.selection;
    final insertAt = selection.start >= 0 ? selection.start : text.length;
    final newText = text.replaceRange(
      insertAt,
      selection.end >= 0 ? selection.end : insertAt,
      emoji,
    );
    _msgCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: insertAt + emoji.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final uid = _authService.currentUser?.uid ?? '';
    final textColor = isDark ? Colors.white : Colors.black87;

    return StreamBuilder<GroupChatModel?>(
      stream: _firestore.groupChatStream(widget.groupId),
      initialData: widget.group,
      builder: (context, groupSnap) {
        final group = groupSnap.data;

        // If group becomes null or inactive, pop back
        if (group != null && !group.isActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('This group is no longer active'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          });
        }

        // If user was removed
        if (group != null && !group.isMember(uid)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('You were removed from this group'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          });
        }

        final isAdmin = group?.isAdmin(uid) ?? false;
        final canMessage = group?.membersCanMessage ?? true;

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
          appBar: AppBar(
            backgroundColor:
                isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
            elevation: 0,
            scrolledUnderElevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: isDark
                    ? Colors.white.withAlpha(15)
                    : Colors.black.withAlpha(15),
              ),
            ),
            leading: IconButton(
              icon:
                  Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [accent, accent.withAlpha(150)],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        isDark ? const Color(0xFF0D0D0D) : Colors.white,
                    backgroundImage:
                        group != null && group.groupPicUrl.isNotEmpty
                            ? CachedNetworkImageProvider(group.groupPicUrl)
                            : null,
                    child: group == null || group.groupPicUrl.isEmpty
                        ? Icon(Icons.group_rounded,
                            size: 18,
                            color: isDark ? Colors.white38 : Colors.black26)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group?.name ?? 'Group',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${group?.memberCount ?? 0} members',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.info_outline_rounded, color: textColor),
                onPressed: () => Navigator.push(
                  context,
                  SlideRightRoute(
                    page: GroupInfoScreen(groupId: widget.groupId),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Edit mode banner
              if (_editingMessageId != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: accent.withAlpha(20),
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: accent, size: 18),
                      const SizedBox(width: 8),
                      Text('Editing message',
                          style: GoogleFonts.inter(
                              color: accent,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _cancelEdit,
                        child: Icon(Icons.close, color: accent, size: 20),
                      ),
                    ],
                  ),
                ),
              if (_uploading)
                LinearProgressIndicator(color: accent, minHeight: 2),
              Expanded(
                child: StreamBuilder<List<GroupMessageModel>>(
                  stream: _groupService.getMessages(widget.groupId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(
                            color: accent, strokeWidth: 2),
                      );
                    }
                    final messages = snapshot.data!;
                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? const Color(0xFF1A1A2E)
                                    : Colors.grey[100],
                              ),
                              child: const Icon(Icons.chat_bubble_outline_rounded,
                                  color: Colors.grey, size: 32),
                            ),
                            const SizedBox(height: 16),
                            Text('No messages yet',
                                style: GoogleFonts.inter(
                                    color: Colors.grey,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text('Start the conversation!',
                                style: GoogleFonts.inter(
                                    color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scrollCtrl,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[messages.length - 1 - index];
                        final isMe = msg.senderUid == uid;

                        final prevMsg = index < messages.length - 1
                            ? messages[messages.length - 2 - index]
                            : null;
                        final showAvatar = !isMe &&
                            (prevMsg == null ||
                                prevMsg.senderUid != msg.senderUid);

                        return Padding(
                          padding: EdgeInsets.only(
                            top: prevMsg != null &&
                                    prevMsg.senderUid != msg.senderUid
                                ? 10
                                : 2,
                            bottom: 2,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: showAvatar
                                      ? FutureBuilder<UserModel?>(
                                          future:
                                              _getCachedUser(msg.senderUid),
                                          builder: (ctx, snap) {
                                            final sender = snap.data;
                                            return CircleAvatar(
                                              radius: 14,
                                              backgroundColor: isDark
                                                  ? const Color(0xFF252540)
                                                  : Colors.grey[200],
                                              backgroundImage: sender
                                                          ?.profilePicUrl
                                                          .isNotEmpty ==
                                                      true
                                                  ? CachedNetworkImageProvider(
                                                      sender!.profilePicUrl)
                                                  : null,
                                              child: sender?.profilePicUrl
                                                          .isEmpty !=
                                                      false
                                                  ? Icon(Icons.person,
                                                      size: 12,
                                                      color: isDark
                                                          ? Colors.white38
                                                          : Colors.black26)
                                                  : null,
                                            );
                                          },
                                        )
                                      : const SizedBox(width: 28),
                                ),
                              Flexible(
                                child: GestureDetector(
                                  onLongPress: (isMe || isAdmin)
                                      ? () => _showMessageOptions(
                                          msg, isAdmin)
                                      : null,
                                  child: Column(
                                    crossAxisAlignment: isMe
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      if (showAvatar)
                                        FutureBuilder<UserModel?>(
                                          future:
                                              _getCachedUser(msg.senderUid),
                                          builder: (ctx, snap) {
                                            final username =
                                                snap.data?.username ?? '';
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 4, bottom: 4),
                                              child: Text(
                                                username.isNotEmpty
                                                    ? '@$username'
                                                    : 'User',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark
                                                      ? Colors.white54
                                                      : Colors.black45,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      _buildMessageBubble(
                                          msg, isMe, accent, isDark, textColor),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // Emoji panel
              if (_showEmojiPanel)
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white.withAlpha(15)
                            : Colors.black.withAlpha(15),
                      ),
                    ),
                  ),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: _emojis.length,
                    itemBuilder: (ctx, i) => GestureDetector(
                      onTap: () => _insertEmoji(_emojis[i]),
                      child: Center(
                        child: Text(_emojis[i],
                            style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  ),
                ),
              // Input bar or messaging disabled banner
              if (!canMessage && !isAdmin)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white.withAlpha(15)
                            : Colors.black.withAlpha(15),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 16,
                          color: isDark ? Colors.white38 : Colors.black26),
                      const SizedBox(width: 8),
                      Text(
                        'Only admins can send messages',
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white38 : Colors.black26,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else
                SafeArea(
                  top: false,
                  bottom: false,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
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
                        GestureDetector(
                          onTap: _uploading ? null : _pickAndSendImage,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.photo_outlined,
                              color: _uploading
                                  ? (isDark
                                      ? Colors.white24
                                      : Colors.black12)
                                  : accent,
                              size: 24,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(
                              () => _showEmojiPanel = !_showEmojiPanel),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              _showEmojiPanel
                                  ? Icons.keyboard_rounded
                                  : Icons.emoji_emotions_outlined,
                              color: accent,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: _msgCtrl,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            onTap: () {
                              if (_showEmojiPanel) {
                                setState(() => _showEmojiPanel = false);
                              }
                            },
                            style: TextStyle(color: textColor),
                            maxLines: 4,
                            minLines: 1,
                            decoration: InputDecoration(
                              hintText: _editingMessageId != null
                                  ? 'Edit message...'
                                  : 'Message...',
                              hintStyle: TextStyle(
                                color: isDark
                                    ? Colors.white30
                                    : Colors.black26,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withAlpha(10)
                                  : Colors.black.withAlpha(8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _send,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _editingMessageId != null
                                    ? [Colors.orange, Colors.deepOrange]
                                    : [accent, accent.withAlpha(180)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withAlpha(60),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              _editingMessageId != null
                                  ? Icons.check_rounded
                                  : Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(
    GroupMessageModel msg,
    bool isMe,
    Color accent,
    bool isDark,
    Color textColor,
  ) {
    final hasMedia = msg.mediaUrl.isNotEmpty;
    final hasText = msg.text.isNotEmpty;
    final hasSharedContent =
        msg.sharedContentType.isNotEmpty && msg.sharedContentId.isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isMe
            ? accent
            : (isDark
                ? Colors.white.withAlpha(15)
                : Colors.black.withAlpha(10)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (hasMedia)
            GestureDetector(
              onTap: () => _showFullImage(msg.mediaUrl),
              child: ClipRRect(
                borderRadius: hasText
                    ? const BorderRadius.vertical(top: Radius.circular(18))
                    : BorderRadius.circular(18),
                child: CachedNetworkImage(
                  imageUrl: msg.mediaUrl,
                  width: 220,
                  height: 220,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 220,
                    height: 220,
                    color:
                        isDark ? const Color(0xFF252540) : Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                          color: accent, strokeWidth: 2),
                    ),
                  ),
                ),
              ),
            ),
          if (hasSharedContent)
            _buildSharedContentPreview(msg, isMe, accent, isDark),
          if (hasText)
            Padding(
              padding: EdgeInsets.only(
                left: 14,
                right: 14,
                top: hasMedia || hasSharedContent ? 8 : 10,
                bottom: msg.isEdited ? 2 : 10,
              ),
              child: Text(
                msg.text,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isMe
                      ? Colors.white
                      : (isDark
                          ? Colors.white.withAlpha(220)
                          : Colors.black87),
                ),
              ),
            ),
          if (msg.isEdited)
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 8),
              child: Text(
                '(edited)',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: isMe
                      ? Colors.white.withAlpha(150)
                      : (isDark ? Colors.white38 : Colors.black26),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSharedContentPreview(
    GroupMessageModel msg,
    bool isMe,
    Color accent,
    bool isDark,
  ) {
    final type = msg.sharedContentType;
    final isPost = type == 'post';
    return GestureDetector(
      onTap: () => _openSharedContent(type, msg.sharedContentId),
      child: Container(
        margin: const EdgeInsets.only(left: 6, right: 6, top: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isMe ? Colors.white.withAlpha(25) : accent.withAlpha(15),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.sharedThumbnail.isNotEmpty)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                child: CachedNetworkImage(
                  imageUrl: msg.sharedThumbnail,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: double.infinity,
                    height: 160,
                    color:
                        isDark ? const Color(0xFF252540) : Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                          color: accent, strokeWidth: 2),
                    ),
                  ),
                ),
              ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPost
                        ? Icons.photo_library_rounded
                        : Icons.video_library_rounded,
                    size: 16,
                    color: isMe ? Colors.white : accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'View ${isPost ? 'Post' : 'Reel'}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isMe ? Colors.white : accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color:
                        isMe ? Colors.white70 : accent.withAlpha(180),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSharedContent(String type, String contentId) async {
    if (type == 'post') {
      final post = await _firestore.getPost(contentId);
      if (post != null && mounted) {
        final creator = await _firestore.getUser(post.creatorUid);
        final currentUid = _authService.currentUser?.uid ?? '';
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(
                post: post,
                creator: creator,
                isOwn: post.creatorUid == currentUid,
              ),
            ),
          );
        }
      }
    }
  }

  void _showFullImage(String url) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }
}

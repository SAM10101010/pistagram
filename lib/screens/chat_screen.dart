import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/messaging_service.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel? partner;
  const ChatScreen({super.key, required this.chatId, this.partner});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messagingService = MessagingService();
  final _authService = AuthService();
  final _cloudinary = CloudinaryService();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _picker = ImagePicker();

  bool _showEmojiPanel = false;
  bool _uploading = false;
  String? _editingMessageId;

  static const _emojis = [
    '😀',
    '😂',
    '🥹',
    '😍',
    '🥰',
    '😘',
    '😎',
    '🤩',
    '😢',
    '😭',
    '😤',
    '🤯',
    '🥳',
    '😴',
    '🤔',
    '🫡',
    '👍',
    '👎',
    '👏',
    '🙌',
    '🤝',
    '💪',
    '🫶',
    '✌️',
    '❤️',
    '🔥',
    '💯',
    '⭐',
    '🎉',
    '💀',
    '👀',
    '✨',
    '🙏',
    '💕',
    '😈',
    '🤡',
    '💔',
    '🥺',
    '😱',
    '🤮',
  ];

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();

    if (_editingMessageId != null) {
      await _messagingService.editMessage(
        widget.chatId,
        _editingMessageId!,
        text,
      );
      setState(() => _editingMessageId = null);
    } else {
      await _messagingService.sendMessage(
        chatId: widget.chatId,
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
        await _messagingService.sendMessage(
          chatId: widget.chatId,
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

  void _startEdit(MessageModel msg) {
    setState(() {
      _editingMessageId = msg.id;
      _msgCtrl.text = msg.text;
      _showEmojiPanel = false;
    });
    // Move cursor to end
    _msgCtrl.selection = TextSelection.collapsed(offset: _msgCtrl.text.length);
  }

  void _cancelEdit() {
    setState(() {
      _editingMessageId = null;
      _msgCtrl.clear();
    });
  }

  Future<void> _deleteMessage(MessageModel msg) async {
    await _messagingService.deleteMessage(widget.chatId, msg.id);
  }

  void _showMessageOptions(MessageModel msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;

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
            if (msg.text.isNotEmpty)
              ListTile(
                leading: Icon(Icons.edit_outlined, color: accent),
                title: Text(
                  'Edit Message',
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _startEdit(msg);
                },
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: Text(
                'Delete Message',
                style: GoogleFonts.inter(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w500,
                ),
              ),
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
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D0D)
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF0D0D0D)
            : const Color(0xFFF8F9FA),
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
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
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
                backgroundColor: isDark
                    ? const Color(0xFF0D0D0D)
                    : Colors.white,
                backgroundImage:
                    widget.partner?.profilePicUrl.isNotEmpty == true
                    ? CachedNetworkImageProvider(widget.partner!.profilePicUrl)
                    : null,
                child: widget.partner?.profilePicUrl.isEmpty != false
                    ? Icon(
                        Icons.person,
                        size: 16,
                        color: isDark ? Colors.white38 : Colors.black26,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '@${widget.partner?.username ?? ''}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Edit mode banner
          if (_editingMessageId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: accent.withAlpha(20),
              child: Row(
                children: [
                  Icon(Icons.edit, color: accent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Editing message',
                    style: GoogleFonts.inter(
                      color: accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _cancelEdit,
                    child: Icon(Icons.close, color: accent, size: 20),
                  ),
                ],
              ),
            ),
          // Upload progress
          if (_uploading) LinearProgressIndicator(color: accent, minHeight: 2),
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _messagingService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: accent,
                      strokeWidth: 2,
                    ),
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
                          child: Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Colors.grey,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: GoogleFonts.inter(
                            color: Colors.grey,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Say hello!',
                          style: GoogleFonts.inter(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[messages.length - 1 - index];
                    final isMe = msg.senderUid == uid;

                    // Check if previous message (visually above) is from same sender
                    final prevMsg = index < messages.length - 1
                        ? messages[messages.length - 2 - index]
                        : null;
                    final showAvatar =
                        !isMe &&
                        (prevMsg == null || prevMsg.senderUid != msg.senderUid);

                    return Padding(
                      padding: EdgeInsets.only(
                        top:
                            prevMsg != null &&
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
                                  ? CircleAvatar(
                                      radius: 14,
                                      backgroundColor: isDark
                                          ? const Color(0xFF252540)
                                          : Colors.grey[200],
                                      backgroundImage:
                                          widget
                                                  .partner
                                                  ?.profilePicUrl
                                                  .isNotEmpty ==
                                              true
                                          ? CachedNetworkImageProvider(
                                              widget.partner!.profilePicUrl,
                                            )
                                          : null,
                                      child:
                                          widget
                                                  .partner
                                                  ?.profilePicUrl
                                                  .isEmpty !=
                                              false
                                          ? Icon(
                                              Icons.person,
                                              size: 12,
                                              color: isDark
                                                  ? Colors.white38
                                                  : Colors.black26,
                                            )
                                          : null,
                                    )
                                  : const SizedBox(width: 28),
                            ),
                          Flexible(
                            child: GestureDetector(
                              onLongPress: isMe
                                  ? () => _showMessageOptions(msg)
                                  : null,
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (showAvatar &&
                                      widget.partner?.username != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 4,
                                        bottom: 4,
                                      ),
                                      child: Text(
                                        widget.partner!.username,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black45,
                                        ),
                                      ),
                                    ),
                                  _buildMessageBubble(
                                    msg,
                                    isMe,
                                    accent,
                                    isDark,
                                    textColor,
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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _emojis.length,
                itemBuilder: (ctx, i) => GestureDetector(
                  onTap: () => _insertEmoji(_emojis[i]),
                  child: Center(
                    child: Text(
                      _emojis[i],
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                  // Photo pick button
                  GestureDetector(
                    onTap: _uploading ? null : _pickAndSendImage,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.photo_outlined,
                        color: _uploading
                            ? (isDark ? Colors.white24 : Colors.black12)
                            : accent,
                        size: 24,
                      ),
                    ),
                  ),
                  // Emoji toggle button
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showEmojiPanel = !_showEmojiPanel),
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
                          color: isDark ? Colors.white30 : Colors.black26,
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
                          horizontal: 16,
                          vertical: 10,
                        ),
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
  }

  Widget _buildMessageBubble(
    MessageModel msg,
    bool isMe,
    Color accent,
    bool isDark,
    Color textColor,
  ) {
    final hasMedia = msg.mediaUrl.isNotEmpty;
    final hasText = msg.text.isNotEmpty;
    final isDeepLink = msg.text.contains('pistagram://');

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
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Media image
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
                    color: isDark ? const Color(0xFF252540) : Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        color: accent,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Text content
          if (hasText)
            Padding(
              padding: EdgeInsets.only(
                left: 14,
                right: 14,
                top: hasMedia ? 8 : 10,
                bottom: msg.isEdited ? 2 : 10,
              ),
              child: isDeepLink
                  ? _buildDeepLinkText(
                      msg.text,
                      isMe,
                      accent,
                      isDark,
                      textColor,
                    )
                  : Text(
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
          // Edited indicator
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

  Widget _buildDeepLinkText(
    String text,
    bool isMe,
    Color accent,
    bool isDark,
    Color textColor,
  ) {
    // Parse deep link from text
    final regex = RegExp(r'pistagram://(reel|post|story)/(\S+)');
    final match = regex.firstMatch(text);

    if (match == null) {
      return Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: isMe
              ? Colors.white
              : (isDark ? Colors.white.withAlpha(220) : Colors.black87),
        ),
      );
    }

    final type = match.group(1) ?? '';
    final linkText = text.replaceAll(match.group(0)!, '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (linkText.isNotEmpty)
          Text(
            linkText,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isMe
                  ? Colors.white
                  : (isDark ? Colors.white.withAlpha(220) : Colors.black87),
            ),
          ),
        if (linkText.isNotEmpty) const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isMe ? Colors.white.withAlpha(30) : accent.withAlpha(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                type == 'reel'
                    ? Icons.video_library_rounded
                    : type == 'story'
                    ? Icons.auto_awesome
                    : Icons.photo_library_rounded,
                size: 16,
                color: isMe ? Colors.white : accent,
              ),
              const SizedBox(width: 6),
              Text(
                'Shared ${type == 'reel'
                    ? 'a reel'
                    : type == 'story'
                    ? 'a story'
                    : 'a post'}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isMe ? Colors.white : accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/messaging_service.dart';
import '../services/auth_service.dart';

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
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    await _messagingService.sendMessage(
      chatId: widget.chatId,
      senderUid: _authService.currentUser?.uid ?? '',
      text: text,
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
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: textColor,
            size: 22,
          ),
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
                    final showAvatar = !isMe &&
                        (prevMsg == null || prevMsg.senderUid != msg.senderUid);

                    return Padding(
                      padding: EdgeInsets.only(
                        top: prevMsg != null && prevMsg.senderUid != msg.senderUid ? 10 : 2,
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
                                      backgroundImage: widget.partner
                                                  ?.profilePicUrl.isNotEmpty ==
                                              true
                                          ? CachedNetworkImageProvider(
                                              widget.partner!.profilePicUrl)
                                          : null,
                                      child: widget.partner?.profilePicUrl
                                                  .isEmpty !=
                                              false
                                          ? Icon(Icons.person,
                                              size: 12,
                                              color: isDark
                                                  ? Colors.white38
                                                  : Colors.black26)
                                          : null,
                                    )
                                  : const SizedBox(width: 28),
                            ),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (showAvatar &&
                                    widget.partner?.username != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 4, bottom: 4),
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
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    color: isMe
                                        ? accent
                                        : (isDark
                                            ? Colors.white.withAlpha(15)
                                            : Colors.black.withAlpha(10)),
                                  ),
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.72,
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
                              ],
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
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: TextStyle(
                        color: textColor,
                      ),
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Message...',
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
                          colors: [accent, accent.withAlpha(180)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withAlpha(60),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.send_rounded,
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

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }
}

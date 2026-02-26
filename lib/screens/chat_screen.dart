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
      chatId: widget.chatId, senderUid: _authService.currentUser?.uid ?? '', text: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = _authService.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black87), onPressed: () => Navigator.pop(context)),
        title: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
            backgroundImage: widget.partner?.profilePicUrl.isNotEmpty == true ? CachedNetworkImageProvider(widget.partner!.profilePicUrl) : null,
            child: widget.partner?.profilePicUrl.isEmpty != false ? Icon(Icons.person, size: 16, color: isDark ? Colors.white38 : Colors.black26) : null,
          ),
          const SizedBox(width: 10),
          Text('@${widget.partner?.username ?? ''}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
        ]),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _messagingService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFDD2A7B)));
                final messages = snapshot.data!;
                if (messages.isEmpty) return Center(child: Text('No messages yet', style: GoogleFonts.inter(color: Colors.grey)));
                return ListView.builder(
                  controller: _scrollCtrl, reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[messages.length - 1 - index];
                    final isMe = msg.senderUid == uid;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: isMe ? const Color(0xFFDD2A7B) : (isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10)),
                        ),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                        child: Text(msg.text, style: GoogleFonts.inter(fontSize: 14,
                          color: isMe ? Colors.white : (isDark ? Colors.white.withAlpha(220) : Colors.black87))),
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
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 5, offset: const Offset(0, -2))],
              ),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl, textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Message...', hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                      filled: true, fillColor: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFFF58529), Color(0xFFDD2A7B)])),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() { _msgCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }
}

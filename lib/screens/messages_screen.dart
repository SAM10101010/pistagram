import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  final Map<String, UserModel> _userCache = {};

  Future<UserModel?> _getCachedUser(String uid) async {
    if (_userCache.containsKey(uid)) return _userCache[uid];
    final u = await _firestore.getUser(uid);
    if (u != null) _userCache[uid] = u;
    return u;
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final uid = _auth.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
        elevation: 0,
        title: Text('Messages', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
        ),
      ),
      body: StreamBuilder<List<ChatModel>>(
        stream: _firestore.getUserChats(uid),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: accent));
          }
          final chats = snap.data ?? [];
          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: subColor),
                  const SizedBox(height: 12),
                  Text('No messages yet', style: GoogleFonts.inter(color: subColor, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Start a conversation!', style: GoogleFonts.inter(color: subColor, fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            itemBuilder: (ctx, i) {
              final chat = chats[i];
              final otherUid = chat.participants.firstWhere((p) => p != uid, orElse: () => '');
              return FutureBuilder<UserModel?>(
                future: _getCachedUser(otherUid),
                builder: (ctx, userSnap) {
                  final other = userSnap.data;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
                      backgroundImage: other != null && other.profilePicUrl.isNotEmpty
                          ? CachedNetworkImageProvider(other.profilePicUrl) : null,
                      child: other == null || other.profilePicUrl.isEmpty
                          ? Icon(Icons.person, color: subColor) : null,
                    ),
                    title: Text(
                      other?.username ?? 'User',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textColor, fontSize: 15),
                    ),
                    subtitle: Text(
                      chat.lastMessage,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: subColor, fontSize: 13),
                    ),
                    trailing: Text(
                      timeago.format(chat.lastMessageAt),
                      style: GoogleFonts.inter(color: subColor, fontSize: 11),
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ChatScreen(chatId: chat.chatId, partner: other),
                    )),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

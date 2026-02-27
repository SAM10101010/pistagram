import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/animations.dart';
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
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(15),
          ),
        ),
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
            return _buildShimmerList(isDark);
          }
          final chats = snap.data ?? [];
          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withAlpha(25),
                    ),
                    child: Icon(Icons.chat_bubble_outline_rounded, size: 36, color: accent),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No messages yet',
                    style: GoogleFonts.outfit(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Start a conversation with someone!',
                    style: GoogleFonts.inter(color: subColor, fontSize: 14),
                  ),
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
                  return GestureDetector(
                    onTap: () => Navigator.push(context, SlideRightRoute(
                      page: ChatScreen(chatId: chat.chatId, partner: other),
                    )),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(10),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [accent, accent.withAlpha(150)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                              ),
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
                                backgroundImage: other != null && other.profilePicUrl.isNotEmpty
                                    ? CachedNetworkImageProvider(other.profilePicUrl) : null,
                                child: other == null || other.profilePicUrl.isEmpty
                                    ? Icon(Icons.person, color: subColor) : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  other?.username ?? 'User',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textColor, fontSize: 15),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  chat.lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(color: subColor, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeago.format(chat.lastMessageAt),
                            style: GoogleFonts.inter(color: subColor, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildShimmerList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 6,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const ShimmerLoading(width: 60, height: 60, isCircle: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerLoading(width: 120, height: 14, borderRadius: 6),
                  SizedBox(height: 8),
                  ShimmerLoading(width: 200, height: 12, borderRadius: 6),
                ],
              ),
            ),
            const ShimmerLoading(width: 40, height: 10, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}

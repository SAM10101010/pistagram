import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/messaging_service.dart';
import '../models/user_model.dart';

class ReelShareSheet extends StatefulWidget {
  final String reelId;
  const ReelShareSheet({super.key, required this.reelId});

  static void show(BuildContext context, String reelId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReelShareSheet(reelId: reelId),
    );
  }

  @override
  State<ReelShareSheet> createState() => _ReelShareSheetState();
}

class _ReelShareSheetState extends State<ReelShareSheet> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  final _messaging = MessagingService();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final bg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final currentUid = _auth.currentUser?.uid ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.7,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: subColor.withAlpha(80), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Text('Share', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder(
                  stream: _firestore.getUserChats(currentUid),
                  builder: (ctx, snap) {
                    if (!snap.hasData) return Center(child: CircularProgressIndicator(color: accent));
                    final chats = snap.data!.take(10).toList();
                    if (chats.isEmpty) {
                      return Center(child: Text('No recent chats', style: GoogleFonts.inter(color: subColor)));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: chats.length,
                      itemBuilder: (ctx, i) {
                        final chat = chats[i];
                        final otherUid = chat.participants.firstWhere((p) => p != currentUid, orElse: () => '');
                        return FutureBuilder<UserModel?>(
                          future: _firestore.getUser(otherUid),
                          builder: (ctx, userSnap) {
                            final user = userSnap.data;
                            if (user == null) return const SizedBox.shrink();
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: user.profilePicUrl.isNotEmpty ? CachedNetworkImageProvider(user.profilePicUrl) : null,
                                child: user.profilePicUrl.isEmpty ? const Icon(Icons.person, size: 20) : null,
                              ),
                              title: Text(user.username, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textColor)),
                              trailing: OutlinedButton(
                                onPressed: () async {
                                  await _messaging.sendMessage(
                                    chatId: chat.chatId,
                                    senderUid: currentUid,
                                    text: 'Check out this reel!',
                                    mediaUrl: '',
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Sent to ${user.username}!'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                    );
                                    Navigator.pop(context);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: accent),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text('Send', style: GoogleFonts.inter(fontSize: 12, color: accent)),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              Divider(color: subColor.withAlpha(40)),
              ListTile(
                leading: Icon(Icons.link_rounded, color: textColor),
                title: Text('Copy Link', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: textColor)),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: 'pistagram://reel/${widget.reelId}'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('Link copied!'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  );
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

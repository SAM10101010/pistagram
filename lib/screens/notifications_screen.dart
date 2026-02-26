import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/follow_service.dart';
import 'profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  final _followService = FollowService();
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
        title: Text('Activity', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
        ),
        actions: [
          TextButton(
            onPressed: () => _firestore.markAllNotificationsRead(uid),
            child: Text('Read All', style: GoogleFonts.inter(color: accent, fontSize: 13)),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _firestore.getNotifications(uid),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: accent));
          }
          final notifs = snap.data ?? [];
          if (notifs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 64, color: subColor),
                  const SizedBox(height: 12),
                  Text('No activity yet', style: GoogleFonts.inter(color: subColor, fontSize: 15)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifs.length,
            itemBuilder: (ctx, i) => _buildNotifTile(notifs[i], accent, isDark, textColor, subColor),
          );
        },
      ),
    );
  }

  Widget _buildNotifTile(NotificationModel notif, Color accent, bool isDark, Color textColor, Color subColor) {
    return FutureBuilder<UserModel?>(
      future: _getCachedUser(notif.fromUid),
      builder: (ctx, snap) {
        final sender = snap.data;
        IconData icon;
        switch (notif.type) {
          case 'follow': icon = Icons.person_add; break;
          case 'like': icon = Icons.favorite; break;
          case 'comment': icon = Icons.chat_bubble; break;
          case 'points': icon = Icons.stars; break;
          default: icon = Icons.notifications;
        }

        return Container(
          color: notif.read ? Colors.transparent : (isDark ? accent.withAlpha(15) : accent.withAlpha(20)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
              backgroundImage: sender != null && sender.profilePicUrl.isNotEmpty
                  ? CachedNetworkImageProvider(sender.profilePicUrl) : null,
              child: sender == null || sender.profilePicUrl.isEmpty
                  ? Icon(icon, color: accent, size: 20) : null,
            ),
            title: RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: sender?.username ?? 'Someone',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
                ),
                TextSpan(
                  text: ' ${notif.message}',
                  style: GoogleFonts.inter(fontSize: 14, color: textColor),
                ),
              ]),
            ),
            subtitle: Text(
              timeago.format(notif.createdAt),
              style: GoogleFonts.inter(color: subColor, fontSize: 11),
            ),
            trailing: notif.type == 'follow'
                ? _buildFollowBackButton(notif.fromUid, accent)
                : null,
            onTap: () {
              if (!notif.read) _firestore.markNotificationRead(notif.id);
              if (notif.fromUid.isNotEmpty) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProfileScreen(userId: notif.fromUid),
                ));
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildFollowBackButton(String targetUid, Color accent) {
    return SizedBox(
      width: 90,
      height: 32,
      child: ElevatedButton(
        onPressed: () async {
          final uid = _auth.currentUser?.uid ?? '';
          await _followService.followUser(uid, targetUid);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Following!'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1)),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.zero,
        ),
        child: Text('Follow', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

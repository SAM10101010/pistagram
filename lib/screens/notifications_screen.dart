import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/follow_service.dart';
import '../services/collab_service.dart';
import '../utils/animations.dart';
import 'profile_screen.dart';
import 'follow_requests_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  final _followService = FollowService();
  final _collabService = CollabService();
  final Map<String, UserModel> _userCache = {};
  final Set<String> _handledRequestIds = {};
  final Set<String> _handledCollabIds = {};

  Future<UserModel?> _getCachedUser(String uid) async {
    if (_userCache.containsKey(uid)) {
      return _userCache[uid];
    }
    final u = await _firestore.getUser(uid);
    if (u != null) {
      _userCache[uid] = u;
    }
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
      backgroundColor: isDark
          ? const Color(0xFF0D0D0D)
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
        elevation: 0,
        title: Text(
          'Activity',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () => _firestore.markAllNotificationsRead(uid),
              style: TextButton.styleFrom(
                backgroundColor: accent.withAlpha(25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
              ),
              child: Text(
                'Read All',
                style: GoogleFonts.inter(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _firestore.getNotifications(uid),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _buildShimmerLoading(isDark);
          }
          final notifs = snap.data ?? [];
          if (notifs.isEmpty) {
            return Column(
              children: [
                _buildFollowRequestsBanner(uid, accent, isDark, textColor, subColor),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [accent.withAlpha(25), accent.withAlpha(8)],
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withAlpha(18),
                            ),
                            child: Icon(
                              Icons.notifications_none_rounded,
                              size: 48,
                              color: accent.withAlpha(150),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No activity yet',
                          style: GoogleFonts.outfit(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'When someone interacts with you,\nyou\'ll see it here.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: subColor,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifs.length + 1,
            itemBuilder: (ctx, i) {
              if (i == 0) {
                return _buildFollowRequestsBanner(uid, accent, isDark, textColor, subColor);
              }
              return _buildNotifTile(notifs[i - 1], accent, isDark, textColor, subColor);
            },
          );
        },
      ),
    );
  }

  Widget _buildFollowRequestsBanner(
    String uid,
    Color accent,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    return FutureBuilder<List<dynamic>>(
      future: _followService.getPendingRequests(uid),
      builder: (ctx, snap) {
        final count = snap.data?.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              SlideRightRoute(page: const FollowRequestsScreen()),
            );
            if (mounted) setState(() {});
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: accent.withAlpha(15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withAlpha(40)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withAlpha(30),
                  ),
                  child: Icon(
                    Icons.person_add_alt_1_rounded,
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Follow Requests',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count pending request${count == 1 ? '' : 's'}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: subColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, color: subColor, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotifTile(
    NotificationModel notif,
    Color accent,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    return FutureBuilder<UserModel?>(
      future: _getCachedUser(notif.fromUid),
      builder: (ctx, snap) {
        final sender = snap.data;
        IconData icon;
        switch (notif.type) {
          case 'follow':
            icon = Icons.person_add;
            break;
          case 'follow_request':
            icon = Icons.person_add_alt_1;
            break;
          case 'like':
            icon = Icons.favorite;
            break;
          case 'comment':
            icon = Icons.chat_bubble;
            break;
          case 'comment_reply':
            icon = Icons.reply_rounded;
            break;
          case 'comment_like':
            icon = Icons.thumb_up_rounded;
            break;
          case 'message':
            icon = Icons.mail_rounded;
            break;
          case 'points':
            icon = Icons.stars;
            break;
          case 'reward':
            icon = Icons.card_giftcard;
            break;
          case 'tag':
            icon = Icons.person_pin;
            break;
          case 'collab_invite':
            icon = Icons.group_add_rounded;
            break;
          case 'collab_accepted':
            icon = Icons.handshake_rounded;
            break;
          case 'collab_rejected':
            icon = Icons.person_remove_rounded;
            break;
          default:
            icon = Icons.notifications;
        }

        Color iconAccent;
        switch (notif.type) {
          case 'follow':
            iconAccent = Colors.blue;
            break;
          case 'follow_request':
            iconAccent = Colors.teal;
            break;
          case 'like':
            iconAccent = Colors.pinkAccent;
            break;
          case 'comment':
            iconAccent = Colors.green;
            break;
          case 'comment_reply':
            iconAccent = Colors.teal;
            break;
          case 'comment_like':
            iconAccent = Colors.pinkAccent;
            break;
          case 'message':
            iconAccent = Colors.deepPurple;
            break;
          case 'points':
            iconAccent = const Color(0xFFFFD700);
            break;
          case 'reward':
            iconAccent = Colors.amber;
            break;
          case 'tag':
            iconAccent = Colors.orange;
            break;
          case 'collab_invite':
            iconAccent = Colors.deepPurpleAccent;
            break;
          case 'collab_accepted':
            iconAccent = Colors.green;
            break;
          case 'collab_rejected':
            iconAccent = Colors.redAccent;
            break;
          default:
            iconAccent = accent;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(10)
                  : Colors.black.withAlpha(10),
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                if (!notif.read) _firestore.markNotificationRead(notif.id);
                if (notif.fromUid.isNotEmpty) {
                  Navigator.push(
                    context,
                    SlideRightRoute(page: ProfileScreen(userId: notif.fromUid)),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: isDark
                              ? const Color(0xFF252540)
                              : Colors.grey[200],
                          backgroundImage:
                              sender != null && sender.profilePicUrl.isNotEmpty
                              ? CachedNetworkImageProvider(sender.profilePicUrl)
                              : null,
                          child: sender == null || sender.profilePicUrl.isEmpty
                              ? Icon(icon, color: iconAccent, size: 22)
                              : null,
                        ),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: iconAccent.withAlpha(30),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF1A1A2E)
                                    : Colors.white,
                                width: 2,
                              ),
                            ),
                            child: Icon(icon, size: 12, color: iconAccent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: sender?.username ?? 'Someone',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: textColor,
                                  ),
                                ),
                                TextSpan(
                                  text: ' ${notif.message}',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timeago.format(notif.createdAt),
                            style: GoogleFonts.inter(
                              color: subColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (notif.type == 'follow')
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _buildFollowBackButton(notif.fromUid, accent),
                      ),
                    if (notif.type == 'follow_request' && !_handledRequestIds.contains(notif.id))
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _buildFollowRequestButtons(
                          notif,
                          accent,
                          isDark,
                        ),
                      ),
                    if (notif.type == 'collab_invite' && !_handledCollabIds.contains(notif.id))
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _buildCollabInviteButtons(
                          notif,
                          accent,
                          isDark,
                        ),
                      ),
                    if (!notif.read)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
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
              SnackBar(
                content: Text('Following!'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 1),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          elevation: 3,
          shadowColor: accent.withAlpha(80),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          'Follow',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildFollowRequestButtons(
    NotificationModel notif,
    Color accent,
    bool isDark,
  ) {
    final subColor = isDark ? Colors.white54 : Colors.black54;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 30,
          child: ElevatedButton(
            onPressed: () async {
              final uid = _auth.currentUser?.uid ?? '';
              await _followService.acceptRequest(notif.fromUid, uid);
              await _firestore.deleteNotification(notif.id);
              if (mounted) {
                setState(() => _handledRequestIds.add(notif.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Request accepted'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(
              'Accept',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          height: 30,
          child: OutlinedButton(
            onPressed: () async {
              final uid = _auth.currentUser?.uid ?? '';
              await _followService.rejectRequest(notif.fromUid, uid);
              await _firestore.deleteNotification(notif.id);
              if (mounted) setState(() => _handledRequestIds.add(notif.id));
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: subColor.withAlpha(80)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(
              'Reject',
              style: GoogleFonts.inter(fontSize: 11, color: subColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollabInviteButtons(
    NotificationModel notif,
    Color accent,
    bool isDark,
  ) {
    final subColor = isDark ? Colors.white54 : Colors.black54;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 30,
          child: ElevatedButton(
            onPressed: () async {
              await _collabService.acceptInvite(notif.id);
              await _firestore.markNotificationRead(notif.id);
              if (mounted) {
                setState(() => _handledCollabIds.add(notif.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Collab accepted! Content shared to your profile.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(
              'Accept',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          height: 30,
          child: OutlinedButton(
            onPressed: () async {
              await _collabService.rejectInvite(notif.id);
              await _firestore.markNotificationRead(notif.id);
              if (mounted) setState(() => _handledCollabIds.add(notif.id));
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: subColor.withAlpha(80)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(
              'Decline',
              style: GoogleFonts.inter(fontSize: 11, color: subColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      itemCount: 8,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const ShimmerLoading(width: 48, height: 48, isCircle: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerLoading(width: 180, height: 14, borderRadius: 6),
                  SizedBox(height: 8),
                  ShimmerLoading(width: 100, height: 10, borderRadius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

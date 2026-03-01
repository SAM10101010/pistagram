import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/group_chat_model.dart';
import '../models/group_invite_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/group_chat_service.dart';
import '../utils/animations.dart';
import 'chat_screen.dart';
import 'group_chat_screen.dart';
import 'create_group_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with TickerProviderStateMixin {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  final _groupService = GroupChatService();
  final Map<String, UserModel> _userCache = {};
  final Map<String, bool> _blockCache = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

  Future<bool> _isBlockedCached(String otherUid) async {
    if (_blockCache.containsKey(otherUid)) {
      return _blockCache[otherUid]!;
    }
    final myUid = _auth.currentUser?.uid ?? '';
    if (myUid.isEmpty) return false;
    final blocked = await _firestore.isBlockedByEither(myUid, otherUid);
    _blockCache[otherUid] = blocked;
    return blocked;
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Messages',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: accent,
                indicatorWeight: 2.5,
                labelColor: textColor,
                unselectedLabelColor: subColor,
                labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, fontSize: 14),
                unselectedLabelStyle:
                    GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 14),
                tabs: const [
                  Tab(text: 'Direct'),
                  Tab(text: 'Groups'),
                ],
              ),
              Container(
                height: 1,
                color: isDark
                    ? Colors.white.withAlpha(15)
                    : Colors.black.withAlpha(15),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDirectTab(isDark, accent, textColor, subColor),
          _buildGroupsTab(isDark, accent, textColor, subColor),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // DIRECT MESSAGES TAB
  // ═══════════════════════════════════════
  Widget _buildDirectTab(
      bool isDark, Color accent, Color textColor, Color subColor) {
    final uid = _auth.currentUser?.uid ?? '';
    return StreamBuilder<List<ChatModel>>(
      stream: _firestore.getUserChats(uid),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _buildShimmerList(isDark);
        }
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: subColor),
                const SizedBox(height: 12),
                Text(
                  'Could not load messages',
                  style: GoogleFonts.inter(color: subColor, fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() {}),
                  child: Text('Retry',
                      style: GoogleFonts.inter(color: accent)),
                ),
              ],
            ),
          );
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
                  child: Icon(Icons.chat_bubble_outline_rounded,
                      size: 36, color: accent),
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
            final otherUid = chat.participants.firstWhere(
              (p) => p != uid,
              orElse: () => '',
            );
            return FutureBuilder<UserModel?>(
              future: _getCachedUser(otherUid),
              builder: (ctx, userSnap) {
                final other = userSnap.data;
                return FutureBuilder<bool>(
                  future: _isBlockedCached(otherUid),
                  builder: (ctx, blockSnap) {
                    final isBlocked = blockSnap.data ?? false;
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        SlideRightRoute(
                          page:
                              ChatScreen(chatId: chat.chatId, partner: other),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF1A1A2E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withAlpha(10)
                                : Colors.black.withAlpha(10),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isBlocked
                                    ? null
                                    : LinearGradient(
                                        colors: [accent, accent.withAlpha(150)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                color: isBlocked
                                    ? (isDark ? Colors.white.withAlpha(15) : Colors.grey[300])
                                    : null,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? const Color(0xFF1A1A2E)
                                      : Colors.white,
                                ),
                                child: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: isDark
                                      ? const Color(0xFF1A1A2E)
                                      : Colors.grey[200],
                                  backgroundImage: !isBlocked &&
                                          other != null &&
                                          other.profilePicUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(
                                          other.profilePicUrl)
                                      : null,
                                  child: isBlocked ||
                                          other == null ||
                                          other.profilePicUrl.isEmpty
                                      ? Icon(
                                          isBlocked ? Icons.block : Icons.person,
                                          color: isBlocked
                                              ? Colors.redAccent.withAlpha(150)
                                              : subColor,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isBlocked
                                        ? 'Blocked Account'
                                        : (other?.username ?? 'User'),
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      color: isBlocked ? subColor : textColor,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isBlocked
                                        ? 'You can\'t message this account'
                                        : chat.lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                        color: subColor, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!isBlocked)
                              Text(
                                timeago.format(chat.lastMessageAt),
                                style: GoogleFonts.inter(
                                    color: subColor, fontSize: 11),
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
        );
      },
    );
  }

  // ═══════════════════════════════════════
  // GROUPS TAB
  // ═══════════════════════════════════════
  Widget _buildGroupsTab(
      bool isDark, Color accent, Color textColor, Color subColor) {
    final uid = _auth.currentUser?.uid ?? '';
    return Stack(
      children: [
        Column(
          children: [
            // Pending invitations banner
            StreamBuilder<List<GroupInviteModel>>(
              stream: _groupService.getPendingInvitations(uid),
              builder: (ctx, inviteSnap) {
                final invites = inviteSnap.data ?? [];
                if (invites.isEmpty) return const SizedBox.shrink();
                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: accent.withAlpha(15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withAlpha(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.group_add_rounded,
                              size: 18, color: accent),
                          const SizedBox(width: 8),
                          Text(
                            '${invites.length} pending invitation${invites.length > 1 ? 's' : ''}',
                            style: GoogleFonts.inter(
                              color: accent,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...invites.map((inv) => _buildInviteTile(
                          inv, isDark, accent, textColor, subColor)),
                    ],
                  ),
                );
              },
            ),
            // Group list
            Expanded(
              child: StreamBuilder<List<GroupChatModel>>(
                stream: _groupService.getUserGroups(uid),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return _buildShimmerList(isDark);
                  }
                  final groups = snap.data ?? [];
                  if (groups.isEmpty) {
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
                            child: Icon(Icons.groups_rounded,
                                size: 36, color: accent),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No groups yet',
                            style: GoogleFonts.outfit(
                              color: textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Create a group to start chatting!',
                            style: GoogleFonts.inter(
                                color: subColor, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: groups.length,
                    itemBuilder: (ctx, i) {
                      final group = groups[i];
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          SlideRightRoute(
                            page: GroupChatScreen(
                                groupId: group.id, group: group),
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1A1A2E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withAlpha(10)
                                  : Colors.black.withAlpha(10),
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
                                    color: isDark
                                        ? const Color(0xFF1A1A2E)
                                        : Colors.white,
                                  ),
                                  child: CircleAvatar(
                                    radius: 28,
                                    backgroundColor: isDark
                                        ? const Color(0xFF1A1A2E)
                                        : Colors.grey[200],
                                    backgroundImage:
                                        group.groupPicUrl.isNotEmpty
                                            ? CachedNetworkImageProvider(
                                                group.groupPicUrl)
                                            : null,
                                    child: group.groupPicUrl.isEmpty
                                        ? Icon(Icons.group_rounded,
                                            color: subColor)
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      group.name,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      group.lastMessage.isNotEmpty
                                          ? group.lastMessage
                                          : '${group.memberCount} members',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                          color: subColor, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeago.format(group.lastMessageAt),
                                style: GoogleFonts.inter(
                                    color: subColor, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        // FAB to create group
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => Navigator.push(
              context,
              SlideRightRoute(page: const CreateGroupScreen()),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.group_add_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildInviteTile(GroupInviteModel invite, bool isDark, Color accent,
      Color textColor, Color subColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: FutureBuilder<UserModel?>(
              future: _getCachedUser(invite.inviterUid),
              builder: (ctx, snap) {
                final inviter = snap.data;
                return Text(
                  '@${inviter?.username ?? '...'} invited you to "${invite.groupName}"',
                  style: GoogleFonts.inter(color: textColor, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              await _groupService.acceptInvitation(invite.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Joined "${invite.groupName}"'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('Accept',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () async {
              await _groupService.declineInvitation(invite.id);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(15) : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('Decline',
                  style: GoogleFonts.inter(
                      color: subColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
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

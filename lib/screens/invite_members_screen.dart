import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/group_chat_service.dart';

class InviteMembersScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  const InviteMembersScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });
  @override
  State<InviteMembersScreen> createState() => _InviteMembersScreenState();
}

class _InviteMembersScreenState extends State<InviteMembersScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  final _groupService = GroupChatService();
  final _searchCtrl = TextEditingController();

  List<UserModel> _results = [];
  List<String> _memberUids = [];
  final Set<String> _pendingInviteUids = {};
  final Set<String> _invitedUids = {};
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final group = await _firestore.getGroupChat(widget.groupId);
    if (group != null && mounted) {
      setState(() => _memberUids = group.members);
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final users = await _firestore.searchUsers(query.trim());
      final uid = _auth.currentUser?.uid ?? '';
      if (mounted) {
        setState(() {
          _results = users.where((u) => u.uid != uid).toList();
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _invite(UserModel user) async {
    setState(() => _pendingInviteUids.add(user.uid));
    try {
      await _groupService.inviteUser(
        groupId: widget.groupId,
        inviterUid: _auth.currentUser?.uid ?? '',
        inviteeUid: user.uid,
      );
      if (mounted) {
        setState(() => _invitedUids.add(user.uid));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation sent to @${user.username}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    if (mounted) setState(() => _pendingInviteUids.remove(user.uid));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
        ),
        title: Text(
          'Invite Members',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: textColor),
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search by username...',
                hintStyle: TextStyle(color: subColor),
                prefixIcon: Icon(Icons.search, color: subColor),
                filled: true,
                fillColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          if (_searching)
            Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(color: accent, strokeWidth: 2),
            )
          else
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _searchCtrl.text.isEmpty
                            ? 'Search users to invite'
                            : 'No users found',
                        style: GoogleFonts.inter(color: subColor, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _results.length,
                      itemBuilder: (ctx, i) {
                        final user = _results[i];
                        final isMember = _memberUids.contains(user.uid);
                        final isInvited = _invitedUids.contains(user.uid);
                        final isPending = _pendingInviteUids.contains(user.uid);

                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 3),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1A1A2E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: isDark
                                    ? const Color(0xFF252540)
                                    : Colors.grey[200],
                                backgroundImage:
                                    user.profilePicUrl.isNotEmpty
                                        ? CachedNetworkImageProvider(
                                            user.profilePicUrl)
                                        : null,
                                child: user.profilePicUrl.isEmpty
                                    ? Icon(Icons.person,
                                        color: subColor, size: 20)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '@${user.username}',
                                      style: GoogleFonts.inter(
                                        color: textColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (user.displayName.isNotEmpty)
                                      Text(
                                        user.displayName,
                                        style: GoogleFonts.inter(
                                          color: subColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isMember)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: subColor.withAlpha(25),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Member',
                                    style: GoogleFonts.inter(
                                      color: subColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )
                              else if (isInvited)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: accent.withAlpha(20),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Invited',
                                    style: GoogleFonts.inter(
                                      color: accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )
                              else
                                GestureDetector(
                                  onTap:
                                      isPending ? null : () => _invite(user),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: accent,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: isPending
                                        ? SizedBox(
                                            width: 14,
                                            height: 14,
                                            child:
                                                CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            'Invite',
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

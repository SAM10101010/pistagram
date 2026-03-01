import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/group_chat_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';
import '../services/group_chat_service.dart';
import '../utils/animations.dart';
import 'invite_members_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  const GroupInfoScreen({super.key, required this.groupId});
  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  final _groupService = GroupChatService();
  final _cloudinary = CloudinaryService();
  final _picker = ImagePicker();

  List<UserModel> _members = [];
  bool _loadingMembers = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final members = await _groupService.getGroupMembers(widget.groupId);
      if (mounted) setState(() => _members = members);
    } catch (_) {}
    if (mounted) setState(() => _loadingMembers = false);
  }

  Future<void> _changeGroupPic(GroupChatModel group) async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    try {
      final result =
          await _cloudinary.uploadFile(File(picked.path), folder: 'group_pics');
      final url = result['url'] ?? '';
      if (url.isNotEmpty) {
        final uid = _auth.currentUser?.uid ?? '';
        await _groupService.updateGroupInfo(widget.groupId, uid,
            groupPicUrl: url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _editName(GroupChatModel group) async {
    final ctrl = TextEditingController(text: group.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black87;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          title: Text('Edit Group Name', style: TextStyle(color: textColor)),
          content: TextField(
            controller: ctrl,
            style: TextStyle(color: textColor),
            maxLength: 50,
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? Colors.white.withAlpha(10) : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text('Save',
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.primary,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
    if (result != null && result.isNotEmpty && result != group.name) {
      final uid = _auth.currentUser?.uid ?? '';
      await _groupService.updateGroupInfo(widget.groupId, uid, name: result);
    }
  }

  Future<void> _toggleSetting(
      GroupChatModel group, String key, bool value) async {
    final uid = _auth.currentUser?.uid ?? '';
    await _groupService.updateGroupSettings(widget.groupId, uid, {key: value});
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          title: Text('Leave Group',
              style:
                  TextStyle(color: isDark ? Colors.white : Colors.black87)),
          content: Text('Are you sure you want to leave this group?',
              style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Leave',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      final uid = _auth.currentUser?.uid ?? '';
      await _groupService.leaveGroup(widget.groupId, uid);
      if (mounted) {
        Navigator.of(context)..pop()..pop(); // pop info + chat
      }
    }
  }

  Future<void> _removeMember(UserModel user, GroupChatModel group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          title: Text('Remove Member',
              style:
                  TextStyle(color: isDark ? Colors.white : Colors.black87)),
          content: Text('Remove @${user.username} from the group?',
              style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      final uid = _auth.currentUser?.uid ?? '';
      await _groupService.removeMember(widget.groupId, uid, user.uid);
      _loadMembers();
    }
  }

  void _showMemberOptions(UserModel user, GroupChatModel group) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;
    final uid = _auth.currentUser?.uid ?? '';
    final targetIsAdmin = group.admins.contains(user.uid);
    final iAmCreator = group.creatorUid == uid;
    final iAmAdmin = group.admins.contains(uid);

    if (!iAmAdmin || user.uid == uid) return;

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
            if (!targetIsAdmin)
              ListTile(
                leading: Icon(Icons.arrow_upward_rounded, color: accent),
                title: Text('Promote to Admin',
                    style: GoogleFonts.inter(
                        color: textColor, fontWeight: FontWeight.w500)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _groupService.promoteToAdmin(
                      widget.groupId, uid, user.uid);
                  _loadMembers();
                },
              ),
            if (targetIsAdmin && iAmCreator)
              ListTile(
                leading: Icon(Icons.arrow_downward_rounded, color: Colors.orange),
                title: Text('Demote from Admin',
                    style: GoogleFonts.inter(
                        color: textColor, fontWeight: FontWeight.w500)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _groupService.demoteAdmin(
                      widget.groupId, uid, user.uid);
                  _loadMembers();
                },
              ),
            if (user.uid != group.creatorUid)
              ListTile(
                leading:
                    const Icon(Icons.person_remove_rounded, color: Colors.redAccent),
                title: Text('Remove from Group',
                    style: GoogleFonts.inter(
                        color: Colors.redAccent, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeMember(user, group);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final uid = _auth.currentUser?.uid ?? '';

    return StreamBuilder<GroupChatModel?>(
      stream: _firestore.groupChatStream(widget.groupId),
      builder: (context, snap) {
        final group = snap.data;

        if (group == null) {
          return Scaffold(
            backgroundColor:
                isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
            appBar: AppBar(
              backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
              elevation: 0,
              leading: IconButton(
                icon:
                    Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text('Group Info',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, color: textColor)),
            ),
            body: Center(
              child: CircularProgressIndicator(color: accent, strokeWidth: 2),
            ),
          );
        }

        final isAdmin = group.isAdmin(uid);
        final isCreator = group.creatorUid == uid;

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon:
                  Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Group Info',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, color: textColor)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Group picture
                GestureDetector(
                  onTap: isAdmin ? () => _changeGroupPic(group) : null,
                  child: Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? const Color(0xFF1A1A2E)
                              : Colors.grey[200],
                          border:
                              Border.all(color: accent.withAlpha(60), width: 2),
                          image: group.groupPicUrl.isNotEmpty
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(
                                      group.groupPicUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: group.groupPicUrl.isEmpty
                            ? Icon(Icons.group_rounded,
                                color: accent, size: 36)
                            : null,
                      ),
                      if (isAdmin)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 14, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Group name
                GestureDetector(
                  onTap: isAdmin ? () => _editName(group) : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          group.name,
                          style: GoogleFonts.outfit(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.edit_rounded, size: 16, color: accent),
                      ],
                    ],
                  ),
                ),
                if (group.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(group.description,
                      style: GoogleFonts.inter(color: subColor, fontSize: 13),
                      textAlign: TextAlign.center),
                ],
                const SizedBox(height: 4),
                Text(
                  '${group.memberCount} members  •  Created ${timeago.format(group.createdAt)}',
                  style: GoogleFonts.inter(color: subColor, fontSize: 12),
                ),
                const SizedBox(height: 20),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _actionButton(
                      icon: Icons.person_add_rounded,
                      label: 'Invite',
                      accent: accent,
                      isDark: isDark,
                      textColor: textColor,
                      onTap: () => Navigator.push(
                        context,
                        SlideRightRoute(
                          page: InviteMembersScreen(
                              groupId: widget.groupId,
                              groupName: group.name),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _actionButton(
                      icon: Icons.logout_rounded,
                      label: 'Leave',
                      accent: Colors.redAccent,
                      isDark: isDark,
                      textColor: textColor,
                      onTap: _leaveGroup,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Admin settings
                if (isAdmin) ...[
                  _sectionHeader('Settings', textColor),
                  const SizedBox(height: 8),
                  _settingTile(
                    'Hide Members',
                    'Only admins can see the member list',
                    Icons.visibility_off_rounded,
                    group.hideMembers,
                    (val) => _toggleSetting(group, 'hideMembers', val),
                    isDark,
                    textColor,
                    subColor,
                  ),
                  _settingTile(
                    'Allow Members to Add',
                    'Members can invite other people',
                    Icons.group_add_rounded,
                    group.membersCanAdd,
                    (val) => _toggleSetting(group, 'membersCanAdd', val),
                    isDark,
                    textColor,
                    subColor,
                  ),
                  _settingTile(
                    'Allow Members to Message',
                    'Members can send messages',
                    Icons.chat_rounded,
                    group.membersCanMessage,
                    (val) => _toggleSetting(group, 'membersCanMessage', val),
                    isDark,
                    textColor,
                    subColor,
                  ),
                  const SizedBox(height: 20),
                ],

                // Members
                _sectionHeader(
                    'Members (${group.memberCount})', textColor),
                const SizedBox(height: 8),

                if (group.hideMembers && !isAdmin)
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.visibility_off_rounded,
                            size: 32, color: subColor),
                        const SizedBox(height: 8),
                        Text('Members are hidden by admin',
                            style: GoogleFonts.inter(
                                color: subColor, fontSize: 13)),
                      ],
                    ),
                  )
                else if (_loadingMembers)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                        color: accent, strokeWidth: 2),
                  )
                else
                  ..._members.map((user) => _buildMemberTile(
                      user, group, isAdmin, isCreator, isDark, textColor,
                      subColor, accent)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title, Color textColor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.outfit(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color accent,
    required bool isDark,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: accent.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withAlpha(40)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.inter(
                    color: accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _settingTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onToggle,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: textColor, size: 20),
        title: Text(title,
            style: GoogleFonts.inter(
                color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle,
            style: GoogleFonts.inter(color: subColor, fontSize: 11)),
        value: value,
        onChanged: onToggle,
        dense: true,
      ),
    );
  }

  Widget _buildMemberTile(
    UserModel user,
    GroupChatModel group,
    bool isAdmin,
    bool isCreator,
    bool isDark,
    Color textColor,
    Color subColor,
    Color accent,
  ) {
    final isUserAdmin = group.admins.contains(user.uid);
    final isUserCreator = group.creatorUid == user.uid;

    return GestureDetector(
      onLongPress: isAdmin ? () => _showMemberOptions(user, group) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  isDark ? const Color(0xFF252540) : Colors.grey[200],
              backgroundImage: user.profilePicUrl.isNotEmpty
                  ? CachedNetworkImageProvider(user.profilePicUrl)
                  : null,
              child: user.profilePicUrl.isEmpty
                  ? Icon(Icons.person, color: subColor, size: 18)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@${user.username}',
                      style: GoogleFonts.inter(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  if (user.displayName.isNotEmpty)
                    Text(user.displayName,
                        style:
                            GoogleFonts.inter(color: subColor, fontSize: 12)),
                ],
              ),
            ),
            if (isUserCreator)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Creator',
                    style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              )
            else if (isUserAdmin)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Admin',
                    style: GoogleFonts.inter(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/theme_provider.dart';
import '../models/user_model.dart';
import '../utils/animations.dart';
import 'auth_screen.dart';
import 'blocked_users_screen.dart';
import 'security_settings_screen.dart';
import 'drafts_screen.dart';
import 'support_ticket_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  UserModel? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final uid = _auth.currentUser?.uid ?? '';
      _user = await _firestore.getUser(uid);
    } catch (e) {
      debugPrint('Settings load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _updatePrivacy(String key, dynamic value) async {
    if (_user == null) return;
    final settings = Map<String, dynamic>.from(_user!.privacySettings);
    settings[key] = value;
    await _firestore.updateUser(_user!.uid, {'privacySettings': settings});
    _user = _user!.copyWith(privacySettings: settings);
    setState(() {});
  }

  Future<void> _setAccountType(String type) async {
    if (_user == null) return;
    await _firestore.updateUser(_user!.uid, {'accountType': type});
    _user = _user!.copyWith(accountType: type);
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account set to ${type.toUpperCase()}',
            style: GoogleFonts.inter(),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _togglePointsVisibility() async {
    if (_user == null) return;
    final newVal = !_user!.pointsVisibility;
    await _firestore.updateUser(_user!.uid, {'pointsVisibility': newVal});
    _user = _user!.copyWith(pointsVisibility: newVal);
    setState(() {});
  }

  void _showCloseFriendsManager() {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchCtrl = TextEditingController();
    List<UserModel> searchResults = [];
    List<String> closeFriends = List<String>.from(_user?.closeFriends ?? []);
    Map<String, UserModel> friendCache = {};
    bool searching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollCtrl) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Close Friends',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${closeFriends.length} people',
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search bar
                TextField(
                  controller: searchCtrl,
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search users to add...',
                    hintStyle: GoogleFonts.inter(
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withAlpha(15)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (q) async {
                    if (q.trim().length < 2) {
                      setSheetState(() => searchResults = []);
                      return;
                    }
                    setSheetState(() => searching = true);
                    final results = await _firestore.searchUsers(q.trim());
                    setSheetState(() {
                      searchResults = results
                          .where(
                            (u) =>
                                u.uid != _user!.uid &&
                                !closeFriends.contains(u.uid),
                          )
                          .toList();
                      searching = false;
                    });
                  },
                ),
                const SizedBox(height: 8),

                // Search results
                if (searching)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                if (searchResults.isNotEmpty) ...[
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (ctx, i) {
                        final u = searchResults[i];
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withAlpha(8)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            leading: CircleAvatar(
                              backgroundImage: u.profilePicUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(u.profilePicUrl)
                                  : null,
                              child: u.profilePicUrl.isEmpty
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(
                              u.username,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              u.displayName,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.add_circle_rounded,
                                color: accent,
                              ),
                              onPressed: () {
                                setSheetState(() {
                                  closeFriends.add(u.uid);
                                  friendCache[u.uid] = u;
                                  searchResults.removeAt(i);
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Divider(color: isDark ? Colors.white10 : Colors.black12),
                ],

                // Current close friends list
                Expanded(
                  child: closeFriends.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 48,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No close friends yet',
                                style: GoogleFonts.inter(
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                ),
                              ),
                              Text(
                                'Search and add people above',
                                style: GoogleFonts.inter(
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.black26,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollCtrl,
                          itemCount: closeFriends.length,
                          itemBuilder: (ctx, i) {
                            final uid = closeFriends[i];
                            return FutureBuilder<UserModel?>(
                              future: friendCache.containsKey(uid)
                                  ? Future.value(friendCache[uid])
                                  : _firestore.getUser(uid),
                              builder: (ctx, snap) {
                                if (!snap.hasData) {
                                  return const ListTile(
                                    leading: CircleAvatar(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                }
                                final u = snap.data!;
                                friendCache[uid] = u;
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withAlpha(8)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundImage:
                                          u.profilePicUrl.isNotEmpty
                                          ? CachedNetworkImageProvider(
                                              u.profilePicUrl,
                                            )
                                          : null,
                                      child: u.profilePicUrl.isEmpty
                                          ? const Icon(Icons.person)
                                          : null,
                                    ),
                                    title: Text(
                                      u.username,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    subtitle: Text(
                                      u.displayName,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black54,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_rounded,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () {
                                        setSheetState(() {
                                          closeFriends.removeAt(i);
                                        });
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),

                // Save button
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      await _firestore.updateCloseFriends(
                        _user!.uid,
                        closeFriends,
                      );
                      _user = _user!.copyWith(closeFriends: closeFriends);
                      setState(() {});
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Close friends updated',
                              style: GoogleFonts.inter(),
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                    child: Text(
                      'Save (${closeFriends.length})',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _auth.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action is permanent. All your data will be deleted. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && _user != null) {
      await _firestore.updateUser(_user!.uid, {'accountStatus': 'deleted'});
      await _auth.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final themeProvider = PistagramApp.of(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0D0D0D)
            : const Color(0xFFF8F9FA),
        body: Center(child: CircularProgressIndicator(color: accent)),
      );
    }

    final privacy = _user?.privacySettings ?? {};

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D0D)
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
        elevation: 0,
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ═══ ACCOUNT TYPE ═══
          _buildSectionHeader('ACCOUNT TYPE', textColor),
          _buildRadioTile(
            'Public Account',
            'Anyone can follow and see your posts',
            'public',
            Icons.public_rounded,
            accent,
            isDark,
            textColor,
            subColor,
          ),
          _buildRadioTile(
            'Private Account',
            'Followers only — require follow requests',
            'private',
            Icons.lock_rounded,
            accent,
            isDark,
            textColor,
            subColor,
          ),
          _buildRadioTile(
            'Creator Account',
            'Public with creator analytics and rewards',
            'creator',
            Icons.star_rounded,
            accent,
            isDark,
            textColor,
            subColor,
          ),
          const Divider(height: 32),

          // ═══ PRIVACY ═══
          _buildSectionHeader('PRIVACY', textColor),
          _buildToggleTile(
            Icons.people_alt_rounded,
            'Hide Followers List',
            'Others cannot see who follows you',
            privacy['hideFollowers'] ?? false,
            (v) => _updatePrivacy('hideFollowers', v),
            accent,
            isDark,
            textColor,
            subColor,
          ),
          _buildToggleTile(
            Icons.person_search_rounded,
            'Hide Following List',
            'Others cannot see who you follow',
            privacy['hideFollowing'] ?? false,
            (v) => _updatePrivacy('hideFollowing', v),
            accent,
            isDark,
            textColor,
            subColor,
          ),
          _buildToggleTile(
            Icons.visibility_off_rounded,
            'Hide Points Balance',
            'Others cannot see your points',
            privacy['hidePoints'] ?? false,
            (v) => _updatePrivacy('hidePoints', v),
            accent,
            isDark,
            textColor,
            subColor,
          ),
          _buildToggleTile(
            Icons.monetization_on_rounded,
            'Show Points to Others',
            'Display your points on your profile',
            _user?.pointsVisibility ?? true,
            (_) => _togglePointsVisibility(),
            accent,
            isDark,
            textColor,
            subColor,
          ),
          const SizedBox(height: 8),
          // ═══ CLOSE FRIENDS ═══
          _buildSectionHeader('CLOSE FRIENDS', textColor),
          _buildTile(
            icon: Icons.star_rounded,
            title: 'Close Friends',
            subtitle:
                '${_user?.closeFriends.length ?? 0} people — manage your close friends list',
            onTap: _showCloseFriendsManager,
            isDark: isDark,
            textColor: textColor,
            subColor: subColor,
          ),
          const SizedBox(height: 8),
          _buildSectionHeader('MESSAGING', textColor),
          _buildDropdownTile(
            Icons.mail_rounded,
            'Allow Messages From',
            privacy['messagesFrom'] ?? 'everyone',
            [
              {'value': 'everyone', 'label': 'Everyone'},
              {'value': 'followers', 'label': 'Followers Only'},
              {'value': 'none', 'label': 'Nobody'},
            ],
            (v) => _updatePrivacy('messagesFrom', v),
            accent,
            isDark,
            textColor,
            subColor,
          ),
          const Divider(height: 32),

          // ═══ DEFAULT POST VISIBILITY ═══
          _buildSectionHeader('DEFAULT POST VISIBILITY', textColor),
          _buildDropdownTile(
            Icons.visibility_rounded,
            'New Post Visibility',
            privacy['defaultVisibility'] ?? 'public',
            [
              {'value': 'public', 'label': 'Public'},
              {'value': 'followers', 'label': 'Followers Only'},
              {'value': 'private', 'label': 'Only Me'},
            ],
            (v) => _updatePrivacy('defaultVisibility', v),
            accent,
            isDark,
            textColor,
            subColor,
          ),
          const Divider(height: 32),

          // ═══ NOTIFICATIONS ═══
          _buildSectionHeader('NOTIFICATIONS', textColor),
          _buildToggleTile(
            Icons.favorite_rounded,
            'Mute Like Notifications',
            'Stop receiving notifications for likes',
            privacy['muteLikes'] ?? false,
            (v) => _updatePrivacy('muteLikes', v),
            accent,
            isDark,
            textColor,
            subColor,
          ),
          _buildToggleTile(
            Icons.chat_bubble_rounded,
            'Mute Comment Notifications',
            'Stop receiving notifications for comments',
            privacy['muteComments'] ?? false,
            (v) => _updatePrivacy('muteComments', v),
            accent,
            isDark,
            textColor,
            subColor,
          ),
          _buildToggleTile(
            Icons.stars_rounded,
            'Mute Points Notifications',
            'Stop receiving notifications for points earned',
            privacy['mutePoints'] ?? false,
            (v) => _updatePrivacy('mutePoints', v),
            accent,
            isDark,
            textColor,
            subColor,
          ),
          const Divider(height: 32),

          // ═══ APPEARANCE ═══
          _buildSectionHeader('APPEARANCE', textColor),
          _buildTile(
            icon: isDark ? Icons.dark_mode : Icons.light_mode,
            title: 'Dark Mode',
            subtitle: isDark
                ? 'Currently using dark theme'
                : 'Currently using light theme',
            trailing: Switch(
              value: isDark,
              activeColor: accent,
              onChanged: (_) => themeProvider?.toggleTheme(),
            ),
            isDark: isDark,
            textColor: textColor,
            subColor: subColor,
          ),
          const SizedBox(height: 8),
          _buildSectionHeader('ACCENT COLOR', textColor),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(ThemeProvider.accentOptions.length, (i) {
                final color = ThemeProvider.accentOptions[i];
                final name = ThemeProvider.accentNames[i];
                final isSelected = themeProvider?.accentColor == color;
                return ScaleTap(
                  onTap: () => themeProvider?.setAccentColor(color),
                  child: Tooltip(
                    message: name,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withAlpha(128),
                                  blurRadius: 12,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
                );
              }),
            ),
          ),
          const Divider(height: 32),

          // ═══ ACCOUNT ═══
          _buildSectionHeader('ACCOUNT', textColor),
          _buildTile(
            icon: Icons.drafts_rounded,
            title: 'Drafts',
            subtitle: 'View and upload saved drafts',
            onTap: () => Navigator.push(
              context,
              SlideRightRoute(page: const DraftsScreen()),
            ),
            isDark: isDark,
            textColor: textColor,
            subColor: subColor,
          ),
          _buildTile(
            icon: Icons.block_rounded,
            title: 'Blocked Users',
            subtitle: 'Manage blocked accounts',
            onTap: () => Navigator.push(
              context,
              SlideRightRoute(page: const BlockedUsersScreen()),
            ),
            isDark: isDark,
            textColor: textColor,
            subColor: subColor,
          ),
          _buildTile(
            icon: Icons.support_agent_rounded,
            title: 'Help & Support',
            subtitle: 'Submit a ticket or report an issue',
            onTap: () => Navigator.push(
              context,
              SlideRightRoute(page: const SupportTicketScreen()),
            ),
            isDark: isDark,
            textColor: textColor,
            subColor: subColor,
          ),
          _buildTile(
            icon: Icons.security_rounded,
            title: 'Security',
            subtitle: 'Password, devices, account',
            onTap: () => Navigator.push(
              context,
              SlideRightRoute(page: const SecuritySettingsScreen()),
            ),
            isDark: isDark,
            textColor: textColor,
            subColor: subColor,
          ),
          _buildTile(
            icon: Icons.logout_rounded,
            title: 'Log Out',
            subtitle: _auth.currentUser?.email ?? '',
            onTap: _logout,
            isDark: isDark,
            textColor: textColor,
            subColor: subColor,
          ),
          _buildTile(
            icon: Icons.delete_forever_outlined,
            title: 'Delete Account',
            subtitle: 'Permanently delete your account',
            titleColor: Colors.red,
            onTap: _deleteAccount,
            isDark: isDark,
            textColor: textColor,
            subColor: subColor,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── UI Builders ──

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor.withAlpha(120),
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildRadioTile(
    String title,
    String subtitle,
    String type,
    IconData icon,
    Color accent,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    final selected = _user?.accountType == type;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: selected ? accent : subColor),
      title: Text(
        title,
        style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: textColor),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(color: subColor, fontSize: 12),
      ),
      trailing: Radio<String>(
        value: type,
        groupValue: _user?.accountType ?? 'public',
        activeColor: accent,
        onChanged: (v) => _setAccountType(v ?? 'public'),
      ),
      onTap: () => _setAccountType(type),
    );
  }

  Widget _buildToggleTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    Color accent,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: accent),
      title: Text(
        title,
        style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: textColor),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(color: subColor, fontSize: 12),
      ),
      trailing: Switch(value: value, activeColor: accent, onChanged: onChanged),
    );
  }

  Widget _buildDropdownTile(
    IconData icon,
    String title,
    String value,
    List<Map<String, String>> options,
    ValueChanged<String> onChanged,
    Color accent,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    final cardColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: accent),
      title: Text(
        title,
        style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: textColor),
      ),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        dropdownColor: cardColor,
        style: GoogleFonts.inter(
          color: accent,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        items: options
            .map(
              (o) =>
                  DropdownMenuItem(value: o['value'], child: Text(o['label']!)),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String subtitle = '',
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
    required bool isDark,
    required Color textColor,
    required Color subColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(
        icon,
        color: titleColor ?? Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w500,
          color: titleColor ?? textColor,
        ),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: GoogleFonts.inter(color: subColor, fontSize: 12),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

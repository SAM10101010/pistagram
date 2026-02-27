import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/moderation_service.dart';
import '../../models/user_model.dart';
import '../profile_screen.dart';
import '../../utils/animations.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _moderation = ModerationService();
  final _searchController = TextEditingController();

  List<UserModel> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snap = await _firestore.collection('users').limit(50).get();
      final users = snap.docs.map((d) => UserModel.fromMap(d.data())).toList();
      if (mounted) {
        setState(() {
          _users = users;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      _load();
      return;
    }
    setState(() => _loading = true);
    try {
      final snap = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .get();
      final users = snap.docs.map((d) => UserModel.fromMap(d.data())).toList();
      if (mounted) {
        setState(() {
          _users = users;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error searching users: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showActions(UserModel user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

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
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              user.username,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(
              'Status: ${user.accountStatus}',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(
                'View Profile',
                style: GoogleFonts.inter(color: textColor),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  SlideRightRoute(page: ProfileScreen(userId: user.uid)),
                );
              },
            ),
            if (user.accountStatus == 'active')
              ListTile(
                leading: const Icon(
                  Icons.pause_circle_outline,
                  color: Colors.orange,
                ),
                title: Text(
                  'Suspend',
                  style: GoogleFonts.inter(color: Colors.orange),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _moderation.suspendUser(user.uid);
                  _load();
                },
              )
            else
              ListTile(
                leading: const Icon(
                  Icons.play_circle_outline,
                  color: Colors.green,
                ),
                title: Text(
                  'Unsuspend',
                  style: GoogleFonts.inter(color: Colors.green),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _moderation.unsuspendUser(user.uid);
                  _load();
                },
              ),
            ListTile(
              leading: const Icon(Icons.timer, color: Colors.orange),
              title: Text(
                'Temporary Ban (7 days)',
                style: GoogleFonts.inter(color: Colors.orange),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await _moderation.temporaryBan(
                  user.uid,
                  const Duration(days: 7),
                );
                _load();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.redAccent),
              title: Text(
                'Permanent Ban',
                style: GoogleFonts.inter(color: Colors.redAccent),
              ),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Permanent Ban'),
                    content: Text(
                      'Permanently ban ${user.username}? This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text(
                          'Ban',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _moderation.permanentBan(user.uid);
                  _load();
                }
              },
            ),
            const SizedBox(height: 16),
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

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D0D)
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'User Management',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: textColor),
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Search by username...',
                hintStyle: TextStyle(color: subColor),
                prefixIcon: Icon(Icons.search, color: subColor),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withAlpha(15)
                    : Colors.black.withAlpha(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: accent))
                : _users.isEmpty
                ? Center(
                    child: Text(
                      'No users found',
                      style: GoogleFonts.inter(color: subColor),
                    ),
                  )
                : ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (ctx, i) {
                      final user = _users[i];
                      final statusColor = user.accountStatus == 'active'
                          ? Colors.green
                          : Colors.redAccent;
                      return ListTile(
                        onTap: () => _showActions(user),
                        leading: CircleAvatar(
                          backgroundImage: user.profilePicUrl.isNotEmpty
                              ? CachedNetworkImageProvider(user.profilePicUrl)
                              : null,
                          child: user.profilePicUrl.isEmpty
                              ? const Icon(Icons.person, size: 20)
                              : null,
                        ),
                        title: Text(
                          user.username,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        subtitle: Text(
                          user.email,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: subColor,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user.accountStatus,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

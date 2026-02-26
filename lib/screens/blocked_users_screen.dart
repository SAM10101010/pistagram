import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/follow_service.dart';
import '../models/user_model.dart';
import 'profile_screen.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  final _followService = FollowService();

  List<UserModel> _blockedUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = _auth.currentUser?.uid ?? '';
      final blockedUids = await _firestore.getBlockedUids(uid);
      final users = <UserModel>[];
      for (final blockedUid in blockedUids) {
        final user = await _firestore.getUser(blockedUid);
        if (user != null) users.add(user);
      }
      if (mounted) {
        setState(() {
          _blockedUsers = users;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading blocked users: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblock(String blockedUid) async {
    final uid = _auth.currentUser?.uid ?? '';
    await _followService.unblockUser(uid, blockedUid);
    if (mounted) {
      setState(() {
        _blockedUsers.removeWhere((u) => u.uid == blockedUid);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('User unblocked'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Blocked Users', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: textColor), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : _blockedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.block, size: 64, color: subColor),
                      const SizedBox(height: 12),
                      Text('No blocked users', style: GoogleFonts.inter(color: subColor, fontSize: 15)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _blockedUsers.length,
                  itemBuilder: (ctx, i) {
                    final user = _blockedUsers[i];
                    return ListTile(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.uid))),
                      leading: CircleAvatar(
                        backgroundImage: user.profilePicUrl.isNotEmpty ? CachedNetworkImageProvider(user.profilePicUrl) : null,
                        child: user.profilePicUrl.isEmpty ? const Icon(Icons.person, size: 20) : null,
                      ),
                      title: Text(user.username, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textColor)),
                      subtitle: Text(user.displayName, style: GoogleFonts.inter(color: subColor, fontSize: 13)),
                      trailing: OutlinedButton(
                        onPressed: () => _unblock(user.uid),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('Unblock', style: GoogleFonts.inter(fontSize: 12, color: Colors.redAccent)),
                      ),
                    );
                  },
                ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/follow_service.dart';
import '../models/user_model.dart';
import 'profile_screen.dart';

class ReelLikesScreen extends StatefulWidget {
  final String reelId;
  const ReelLikesScreen({super.key, required this.reelId});

  @override
  State<ReelLikesScreen> createState() => _ReelLikesScreenState();
}

class _ReelLikesScreenState extends State<ReelLikesScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  final _followService = FollowService();

  List<UserModel> _users = [];
  Set<String> _followingIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final currentUid = _auth.currentUser?.uid ?? '';
      final snap = await FirebaseFirestore.instance
          .collection('likes')
          .where('reelId', isEqualTo: widget.reelId)
          .get();

      final users = <UserModel>[];
      final following = <String>{};

      for (final doc in snap.docs) {
        final uid = doc.data()['uid'] as String?;
        if (uid == null) continue;
        final user = await _firestore.getUser(uid);
        if (user != null) {
          users.add(user);
          if (uid != currentUid) {
            final isF = await _followService.isFollowing(currentUid, uid);
            if (isF) following.add(uid);
          }
        }
      }
      if (mounted) {
        setState(() {
          _users = users;
          _followingIds = following;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading likes: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow(String targetUid) async {
    final currentUid = _auth.currentUser?.uid ?? '';
    if (_followingIds.contains(targetUid)) {
      await _followService.unfollowUser(currentUid, targetUid);
      _followingIds.remove(targetUid);
    } else {
      await _followService.followUser(currentUid, targetUid);
      _followingIds.add(targetUid);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final currentUid = _auth.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Likes', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: textColor), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : _users.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.favorite_border, size: 64, color: subColor),
                  const SizedBox(height: 12),
                  Text('No likes yet', style: GoogleFonts.inter(color: subColor, fontSize: 15)),
                ]))
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (ctx, i) {
                    final user = _users[i];
                    final isOwn = user.uid == currentUid;
                    final isFollowing = _followingIds.contains(user.uid);

                    return ListTile(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.uid))),
                      leading: CircleAvatar(
                        backgroundImage: user.profilePicUrl.isNotEmpty ? CachedNetworkImageProvider(user.profilePicUrl) : null,
                        child: user.profilePicUrl.isEmpty ? const Icon(Icons.person, size: 20) : null,
                      ),
                      title: Text(user.username, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textColor)),
                      subtitle: Text(user.displayName, style: GoogleFonts.inter(color: subColor, fontSize: 13)),
                      trailing: isOwn
                          ? null
                          : SizedBox(
                              width: 100,
                              height: 34,
                              child: isFollowing
                                  ? OutlinedButton(
                                      onPressed: () => _toggleFollow(user.uid),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: subColor.withAlpha(80)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: EdgeInsets.zero,
                                      ),
                                      child: Text('Following', style: GoogleFonts.inter(fontSize: 12, color: subColor)),
                                    )
                                  : ElevatedButton(
                                      onPressed: () => _toggleFollow(user.uid),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accent,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: EdgeInsets.zero,
                                      ),
                                      child: Text('Follow', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                                    ),
                            ),
                    );
                  },
                ),
    );
  }
}

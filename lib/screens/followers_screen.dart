import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../services/follow_service.dart';
import '../services/auth_service.dart';

class FollowersScreen extends StatefulWidget {
  final String uid;
  final int initialTab;
  const FollowersScreen({super.key, required this.uid, this.initialTab = 0});
  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _followService = FollowService();
  final _authService = AuthService();
  List<UserModel> _followers = [];
  List<UserModel> _following = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _load();
  }

  Future<void> _load() async {
    final followers = await _followService.getFollowers(widget.uid);
    final following = await _followService.getFollowing(widget.uid);
    if (mounted) setState(() { _followers = followers; _following = following; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black87), onPressed: () => Navigator.pop(context)),
        title: Text('Connections', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFFDD2A7B), labelColor: isDark ? Colors.white : Colors.black87,
          unselectedLabelColor: Colors.grey,
          tabs: [Tab(text: 'Followers (${_followers.length})'), Tab(text: 'Following (${_following.length})')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFDD2A7B)))
          : TabBarView(controller: _tabCtrl, children: [
              _buildList(_followers, isDark, true),
              _buildList(_following, isDark, false),
            ]),
    );
  }

  Widget _buildList(List<UserModel> users, bool isDark, bool isFollowers) {
    if (users.isEmpty) {
      return Center(child: Text(isFollowers ? 'No followers yet' : 'Not following anyone',
        style: GoogleFonts.inter(color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
            backgroundImage: user.profilePicUrl.isNotEmpty ? CachedNetworkImageProvider(user.profilePicUrl) : null,
            child: user.profilePicUrl.isEmpty ? Icon(Icons.person, color: isDark ? Colors.white38 : Colors.black26) : null,
          ),
          title: Text('@${user.username}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
          subtitle: user.bio.isNotEmpty ? Text(user.bio, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)) : null,
          trailing: _buildActionButton(user, isDark, isFollowers),
        );
      },
    );
  }

  Widget _buildActionButton(UserModel user, bool isDark, bool isFollowers) {
    final currentUid = _authService.currentUser?.uid ?? '';
    if (user.uid == currentUid) return const SizedBox.shrink();
    return SizedBox(
      width: 90,
      child: OutlinedButton(
        onPressed: () async {
          if (isFollowers) {
            await _followService.removeFollower(currentUid, user.uid);
          } else {
            await _followService.unfollowUser(currentUid, user.uid);
          }
          _load();
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        child: Text(isFollowers ? 'Remove' : 'Unfollow',
          style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
      ),
    );
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }
}

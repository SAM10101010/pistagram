import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../services/follow_service.dart';
import '../services/auth_service.dart';
import '../utils/animations.dart';

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
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black87, size: 22), onPressed: () => Navigator.pop(context)),
        title: Text('Connections', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              TabBar(
                controller: _tabCtrl,
                indicatorColor: accent,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: isDark ? Colors.white : Colors.black87,
                unselectedLabelColor: Colors.grey,
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                tabs: [Tab(text: 'Followers (${_followers.length})'), Tab(text: 'Following (${_following.length})')],
              ),
              Container(height: 1, color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(15)),
            ],
          ),
        ),
      ),
      body: _loading
          ? _buildShimmerList(isDark)
          : TabBarView(controller: _tabCtrl, children: [
              _buildList(_followers, isDark, true),
              _buildList(_following, isDark, false),
            ]),
    );
  }

  Widget _buildList(List<UserModel> users, bool isDark, bool isFollowers) {
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    if (users.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[100]),
            child: Icon(isFollowers ? Icons.people_outline_rounded : Icons.person_add_disabled_rounded, color: subColor, size: 32),
          ),
          const SizedBox(height: 16),
          Text(isFollowers ? 'No followers yet' : 'Not following anyone', style: GoogleFonts.inter(color: subColor, fontSize: 15, fontWeight: FontWeight.w500)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(10)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [accent, accent.withAlpha(150)]),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
                  backgroundImage: user.profilePicUrl.isNotEmpty ? CachedNetworkImageProvider(user.profilePicUrl) : null,
                  child: user.profilePicUrl.isEmpty ? Icon(Icons.person, color: isDark ? Colors.white38 : Colors.black26, size: 20) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@${user.username}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textColor, fontSize: 15)),
                    if (user.bio.isNotEmpty)
                      Text(user.bio, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, color: subColor)),
                  ],
                ),
              ),
              _buildActionButton(user, isDark, isFollowers),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton(UserModel user, bool isDark, bool isFollowers) {
    final currentUid = _authService.currentUser?.uid ?? '';
    if (user.uid == currentUid) return const SizedBox.shrink();
    return SizedBox(
      height: 34,
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
          side: BorderSide(color: isDark ? Colors.white.withAlpha(40) : Colors.black.withAlpha(30)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Text(isFollowers ? 'Remove' : 'Unfollow',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
      ),
    );
  }

  Widget _buildShimmerList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: 8,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          const ShimmerLoading(width: 48, height: 48, isCircle: true),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            ShimmerLoading(width: 120, height: 14, borderRadius: 6),
            SizedBox(height: 8),
            ShimmerLoading(width: 80, height: 10, borderRadius: 6),
          ])),
          const ShimmerLoading(width: 70, height: 34, borderRadius: 20),
        ]),
      ),
    );
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }
}

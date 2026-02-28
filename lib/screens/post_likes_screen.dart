import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../utils/animations.dart';
import 'profile_screen.dart';

class PostLikesScreen extends StatefulWidget {
  final String postId;
  const PostLikesScreen({super.key, required this.postId});

  @override
  State<PostLikesScreen> createState() => _PostLikesScreenState();
}

class _PostLikesScreenState extends State<PostLikesScreen> {
  final _firestore = FirestoreService();
  List<UserModel> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await _firestore.getPostLikers(widget.postId);
      if (mounted) {
        setState(() {
          _users = users;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading post likers: $e');
      if (mounted) setState(() => _loading = false);
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
        backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Likes', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
        centerTitle: true,
      ),
      body: _loading
          ? _buildShimmerList(isDark)
          : _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[100],
                        ),
                        child: Icon(Icons.favorite_border_rounded, color: subColor, size: 32),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No likes yet',
                        style: GoogleFonts.inter(color: subColor, fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return GestureDetector(
                      onTap: () => Navigator.push(context, SlideRightRoute(page: ProfileScreen(userId: user.uid))),
                      child: Container(
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
                                backgroundImage: user.profilePicUrl.isNotEmpty
                                    ? CachedNetworkImageProvider(user.profilePicUrl)
                                    : null,
                                child: user.profilePicUrl.isEmpty
                                    ? Icon(Icons.person, color: isDark ? Colors.white38 : Colors.black26, size: 20)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '@${user.username}',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textColor, fontSize: 15),
                                  ),
                                  if (user.bio.isNotEmpty)
                                    Text(
                                      user.bio,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(fontSize: 12, color: subColor),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
        child: Row(
          children: const [
            ShimmerLoading(width: 48, height: 48, isCircle: true),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLoading(width: 120, height: 14, borderRadius: 6),
                  SizedBox(height: 8),
                  ShimmerLoading(width: 80, height: 10, borderRadius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

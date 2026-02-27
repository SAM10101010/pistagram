import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/reel_model.dart';
import '../services/firestore_service.dart';
import '../utils/animations.dart';
import 'search_screen.dart';
import 'trending_reels_screen.dart';
import 'reel_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<ReelModel> _trending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    try {
      _trending = await _firestore.getTrendingReels(limit: 30);
    } catch (e) {
      debugPrint('Explore load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, SlideRightRoute(page: const SearchScreen())),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(15)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded, color: subColor, size: 20),
                            const SizedBox(width: 10),
                            Text('Search users, hashtags...', style: GoogleFonts.inter(color: subColor, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _loading
                  ? _buildShimmerGrid(isDark)
                  : _trending.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72, height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[100],
                                ),
                                child: Icon(Icons.explore_off_rounded, color: subColor, size: 36),
                              ),
                              const SizedBox(height: 16),
                              Text('No trending reels yet', style: GoogleFonts.inter(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('Check back soon!', style: GoogleFonts.inter(color: subColor, fontSize: 13)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: accent,
                          onRefresh: () async {
                            setState(() => _loading = true);
                            _trending.clear();
                            await _loadTrending();
                          },
                          child: CustomScrollView(
                            slivers: [
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: accent.withAlpha(15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.local_fire_department_rounded, color: accent, size: 18),
                                            const SizedBox(width: 6),
                                            Text('Trending', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: accent)),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      GestureDetector(
                                        onTap: () => Navigator.push(context, SlideRightRoute(page: const TrendingReelsScreen())),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: accent.withAlpha(60)),
                                          ),
                                          child: Text('See All', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: accent)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SliverToBoxAdapter(child: SizedBox(height: 8)),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                sliver: SliverGrid(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 0.75,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (ctx, i) {
                                      final reel = _trending[i];
                                      return GestureDetector(
                                        onTap: () => Navigator.push(context, SlideRightRoute(page: ReelDetailScreen(reelId: reel.reelId))),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              CachedNetworkImage(
                                                imageUrl: reel.thumbnailUrl.isNotEmpty ? reel.thumbnailUrl : 'https://picsum.photos/200/300?random=${reel.reelId.hashCode}',
                                                fit: BoxFit.cover,
                                                placeholder: (c, u) => Container(
                                                  decoration: BoxDecoration(
                                                    color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(12),
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                                    colors: [Colors.transparent, Colors.black.withAlpha(150)],
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                bottom: 8, left: 8,
                                                child: Row(children: [
                                                  const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
                                                  const SizedBox(width: 2),
                                                  Text(_formatCount(reel.viewsCount), style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                                ]),
                                              ),
                                              Positioned(
                                                bottom: 8, right: 8,
                                                child: Row(children: [
                                                  const Icon(Icons.favorite_rounded, color: Colors.white, size: 12),
                                                  const SizedBox(width: 2),
                                                  Text(_formatCount(reel.likesCount), style: GoogleFonts.inter(color: Colors.white, fontSize: 10)),
                                                ]),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    childCount: _trending.length,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerGrid(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 0.75,
      ),
      itemCount: 12,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const ShimmerLoading(borderRadius: 12),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

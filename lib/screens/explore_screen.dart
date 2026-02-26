import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/reel_model.dart';
import '../services/firestore_service.dart';
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
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
        elevation: 0,
        title: Text('Explore', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
            icon: Icon(Icons.search_rounded, color: textColor, size: 26),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : _trending.isEmpty
              ? Center(child: Text('No trending reels yet', style: GoogleFonts.inter(color: subColor)))
              : RefreshIndicator(
                  onRefresh: () async {
                    setState(() => _loading = true);
                    _trending.clear();
                    await _loadTrending();
                  },
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Trending', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
                              GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrendingReelsScreen())),
                                child: Text('See All', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: accent)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2, childAspectRatio: 0.75,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final reel = _trending[i];
                            return GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReelDetailScreen(reelId: reel.reelId))),
                              child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: reel.thumbnailUrl.isNotEmpty ? reel.thumbnailUrl : 'https://picsum.photos/200/300?random=${reel.reelId.hashCode}',
                              fit: BoxFit.cover,
                              placeholder: (c, u) => Container(color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200]),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withAlpha(150)],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 6, left: 6,
                              child: Row(children: [
                                const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                                const SizedBox(width: 2),
                                Text(_formatCount(reel.viewsCount), style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                            Positioned(
                              bottom: 6, right: 6,
                              child: Row(children: [
                                const Icon(Icons.favorite, color: Colors.white, size: 12),
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
            ],
          ),
        ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

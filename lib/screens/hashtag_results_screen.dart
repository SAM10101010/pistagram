import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firestore_service.dart';
import '../models/reel_model.dart';
import 'reel_detail_screen.dart';
import '../utils/animations.dart';

class HashtagResultsScreen extends StatefulWidget {
  final String hashtag;
  const HashtagResultsScreen({super.key, required this.hashtag});

  @override
  State<HashtagResultsScreen> createState() => _HashtagResultsScreenState();
}

class _HashtagResultsScreenState extends State<HashtagResultsScreen> {
  final _firestore = FirestoreService();
  List<ReelModel> _reels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final reels = await _firestore.getReelsByHashtag(widget.hashtag);
      if (mounted) {
        setState(() {
          _reels = reels;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading hashtag results: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
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
        title: Text('#${widget.hashtag}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: textColor), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : _reels.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tag, size: 64, color: subColor),
                      const SizedBox(height: 12),
                      Text('No reels with #${widget.hashtag}', style: GoogleFonts.inter(color: subColor, fontSize: 15)),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Text('${_formatCount(_reels.length)} reels', style: GoogleFonts.inter(fontSize: 13, color: subColor)),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 9 / 16,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemCount: _reels.length,
                        itemBuilder: (ctx, i) {
                          final reel = _reels[i];
                          return GestureDetector(
                            onTap: () => Navigator.push(context, SlideRightRoute(page: ReelDetailScreen(reelId: reel.reelId))),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (reel.thumbnailUrl.isNotEmpty)
                                  CachedNetworkImage(
                                    imageUrl: reel.thumbnailUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200]),
                                    errorWidget: (_, __, ___) => Container(color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200], child: const Icon(Icons.play_arrow, color: Colors.white54)),
                                  )
                                else
                                  Container(color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200], child: const Icon(Icons.play_arrow, color: Colors.white54)),
                                Positioned(
                                  bottom: 6,
                                  left: 6,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                                      const SizedBox(width: 2),
                                      Text(_formatCount(reel.viewsCount), style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ],
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

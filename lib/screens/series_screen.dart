import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/series_model.dart';
import '../models/reel_model.dart';
import '../services/series_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../utils/animations.dart';

class SeriesScreen extends StatefulWidget {
  final String seriesId;
  const SeriesScreen({super.key, required this.seriesId});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  final SeriesService _seriesService = SeriesService();
  final FirestoreService _firestore = FirestoreService();
  final AuthService _auth = AuthService();

  SeriesModel? _series;
  SeriesProgressModel? _progress;
  List<ReelModel?> _reels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final uid = _auth.currentUser?.uid ?? '';
      _series = await _seriesService.getSeries(widget.seriesId);
      if (_series != null) {
        _progress = await _seriesService.getProgress(uid, widget.seriesId);
        // Load reels
        final futures = _series!.reelIds.map((id) => _firestore.getReel(id));
        _reels = await Future.wait(futures);
      }
    } catch (e) {
      debugPrint('Series load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D0D)
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
        ),
        title: Text(
          'Series',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: accent, strokeWidth: 2),
            )
          : _series == null
          ? Center(
              child: Text(
                'Series not found',
                style: GoogleFonts.inter(color: subColor),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Series header
                FadeInSlide(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [accent, accent.withAlpha(160)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withAlpha(50),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (_series!.coverImageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: _series!.coverImageUrl,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        if (_series!.coverImageUrl.isNotEmpty)
                          const SizedBox(height: 16),
                        Text(
                          _series!.title,
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_series!.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            _series!.description,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildHeaderStat(
                              Icons.video_library_rounded,
                              '${_series!.reelIds.length} reels',
                            ),
                            const SizedBox(width: 20),
                            _buildHeaderStat(
                              Icons.stars_rounded,
                              '+${_series!.bonusPoints} pts',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Progress
                FadeInSlide(
                  delay: 100,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withAlpha(10)
                            : Colors.black.withAlpha(10),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progress',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: textColor,
                              ),
                            ),
                            Text(
                              '${_progress?.watchedReelIds.length ?? 0} / ${_series!.reelIds.length}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _progress != null
                                ? _progress!.progress(_series!.reelIds.length)
                                : 0.0,
                            backgroundColor: isDark
                                ? Colors.white.withAlpha(15)
                                : Colors.grey.withAlpha(40),
                            valueColor: AlwaysStoppedAnimation(
                              _progress?.completed == true
                                  ? Colors.green
                                  : accent,
                            ),
                            minHeight: 8,
                          ),
                        ),
                        if (_progress?.completed == true) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.green,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _progress!.bonusAwarded
                                    ? 'Series completed!'
                                    : 'Completed! Bonus awarded.',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Reel list
                Text(
                  'Reels in Series',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(_reels.length, (i) {
                  final reel = _reels[i];
                  if (reel == null) return const SizedBox.shrink();
                  final isWatched =
                      _progress?.watchedReelIds.contains(reel.reelId) ?? false;
                  return FadeInSlide(
                    delay: 150 + i * 50,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isWatched ? accent.withAlpha(10) : cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isWatched
                              ? accent.withAlpha(50)
                              : (isDark
                                    ? Colors.white.withAlpha(10)
                                    : Colors.black.withAlpha(10)),
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: reel.thumbnailUrl.isNotEmpty
                                  ? reel.thumbnailUrl
                                  : 'https://picsum.photos/100/130?random=${reel.reelId.hashCode}',
                              width: 60,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reel.caption.isNotEmpty
                                      ? reel.caption
                                      : 'Reel ${i + 1}',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: textColor,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.play_arrow_rounded,
                                      size: 14,
                                      color: subColor,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${reel.viewsCount} views',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: subColor,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(
                                      Icons.favorite_rounded,
                                      size: 14,
                                      color: subColor,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${reel.likesCount}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: subColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isWatched
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked,
                            color: isWatched ? Colors.green : subColor,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _buildHeaderStat(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

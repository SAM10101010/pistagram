import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uuid/uuid.dart';
import '../models/series_model.dart';
import '../models/reel_model.dart';
import '../services/series_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../utils/animations.dart';

class CreateSeriesScreen extends StatefulWidget {
  const CreateSeriesScreen({super.key});

  @override
  State<CreateSeriesScreen> createState() => _CreateSeriesScreenState();
}

class _CreateSeriesScreenState extends State<CreateSeriesScreen> {
  final SeriesService _seriesService = SeriesService();
  final FirestoreService _firestore = FirestoreService();
  final AuthService _auth = AuthService();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _bonusController = TextEditingController(text: '25');

  List<ReelModel> _myReels = [];
  final Set<String> _selectedReelIds = {};
  bool _loading = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _loadReels();
  }

  Future<void> _loadReels() async {
    final uid = _auth.currentUser?.uid ?? '';
    _myReels = await _firestore.getReelsByUser(uid);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _createSeries() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_selectedReelIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least 2 reels'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _creating = true);
    final uid = _auth.currentUser?.uid ?? '';
    final series = SeriesModel(
      seriesId: const Uuid().v4(),
      creatorUid: uid,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      reelIds: _selectedReelIds.toList(),
      totalReels: _selectedReelIds.length,
      bonusPoints: int.tryParse(_bonusController.text) ?? 25,
    );
    await _seriesService.createSeries(series);
    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Series created!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _bonusController.dispose();
    super.dispose();
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
          'Create Series',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ScaleTap(
              onTap: _creating ? null : _createSeries,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _creating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Create',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: accent, strokeWidth: 2),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Title
                Text(
                  'Title',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  style: GoogleFonts.inter(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'e.g. "Learn Flutter in 5 Steps"',
                    hintStyle: GoogleFonts.inter(color: subColor),
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withAlpha(10)
                            : Colors.black.withAlpha(10),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withAlpha(10)
                            : Colors.black.withAlpha(10),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: accent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  'Description (optional)',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _descController,
                  style: GoogleFonts.inter(color: textColor),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Describe what this series is about',
                    hintStyle: GoogleFonts.inter(color: subColor),
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withAlpha(10)
                            : Colors.black.withAlpha(10),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withAlpha(10)
                            : Colors.black.withAlpha(10),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: accent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Bonus points
                Text(
                  'Completion Bonus Points',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _bonusController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(color: textColor),
                  decoration: InputDecoration(
                    hintText: '25',
                    hintStyle: GoogleFonts.inter(color: subColor),
                    filled: true,
                    fillColor: cardColor,
                    prefixIcon: Icon(
                      Icons.stars_rounded,
                      color: const Color(0xFFFFD700),
                      size: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withAlpha(10)
                            : Colors.black.withAlpha(10),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withAlpha(10)
                            : Colors.black.withAlpha(10),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: accent),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Select reels
                Row(
                  children: [
                    Text(
                      'Select Reels',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_selectedReelIds.length}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to select reels for your series (min 2)',
                  style: GoogleFonts.inter(fontSize: 12, color: subColor),
                ),
                const SizedBox(height: 12),

                if (_myReels.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No reels found. Upload some reels first!',
                        style: GoogleFonts.inter(color: subColor),
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          childAspectRatio: 0.75,
                        ),
                    itemCount: _myReels.length,
                    itemBuilder: (ctx, i) {
                      final reel = _myReels[i];
                      final isSelected = _selectedReelIds.contains(reel.reelId);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedReelIds.remove(reel.reelId);
                            } else {
                              _selectedReelIds.add(reel.reelId);
                            }
                          });
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: reel.thumbnailUrl.isNotEmpty
                                    ? reel.thumbnailUrl
                                    : 'https://picsum.photos/200/300?random=${reel.reelId.hashCode}',
                                fit: BoxFit.cover,
                              ),
                              if (isSelected)
                                Container(
                                  color: accent.withAlpha(100),
                                  child: Center(
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                      child: Icon(
                                        Icons.check,
                                        color: accent,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              if (isSelected)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: accent,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${_selectedReelIds.toList().indexOf(reel.reelId) + 1}',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}

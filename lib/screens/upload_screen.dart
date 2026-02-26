import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import '../models/reel_model.dart';
import '../models/post_model.dart';
import '../models/story_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/cloudinary_service.dart';
import '../services/draft_service.dart';
import 'drafts_screen.dart';

class UploadScreen extends StatefulWidget {
  final DraftModel? draft;
  const UploadScreen({super.key, this.draft});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> with TickerProviderStateMixin {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  final _cloudinary = CloudinaryService();
  final _imagePicker = ImagePicker();
  final _captionCtrl = TextEditingController();
  final _draftService = DraftService();

  // ── State ──
  int _step = 0; // 0=category, 1=select, 2=edit, 3=details
  String _category = 'post'; // post, reel, story
  final List<XFile> _selectedMedia = [];
  VideoPlayerController? _videoCtrl;
  bool _uploading = false;
  double _uploadProgress = 0;

  // Edit state
  int _editIndex = 0;
  String _selectedFilter = 'none';
  final List<Map<String, dynamic>> _stickers = [];
  String _overlayText = '';
  double _textX = 0.5, _textY = 0.3;

  // Video trim
  double _trimStart = 0, _trimEnd = 1.0;

  // Music state
  String? _musicPath;
  String _musicName = '';
  double _musicStart = 0, _musicEnd = 15; // 15-sec music clip
  bool _musicEnabled = false;

  // Post details
  String _visibility = 'public';
  bool _allowComments = true;

  static const _filters = ['none', 'warm', 'cool', 'sepia', 'grayscale', 'vibrant', 'fade', 'noir'];

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  void _restoreDraft() {
    final draft = widget.draft;
    if (draft == null) return;
    _category = draft.category;
    _captionCtrl.text = draft.caption;
    _visibility = draft.visibility;
    _allowComments = draft.allowComments;
    _selectedFilter = draft.filter;
    // Restore media paths if files still exist
    for (final path in draft.mediaPaths) {
      if (File(path).existsSync()) {
        _selectedMedia.add(XFile(path));
      }
    }
    // Skip to details step if we have media
    if (_selectedMedia.isNotEmpty) {
      _step = 3;
    } else {
      _step = 1;
    }
    setState(() {});
  }

  Future<void> _saveDraft() async {
    if (_selectedMedia.isEmpty && _captionCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to save'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final draft = DraftModel(
      id: widget.draft?.id ?? const Uuid().v4(),
      category: _category,
      caption: _captionCtrl.text,
      visibility: _visibility,
      allowComments: _allowComments,
      mediaPaths: _selectedMedia.map((f) => f.path).toList(),
      filter: _selectedFilter,
    );
    await _draftService.saveDraft(draft);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft saved'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  // ── Category Picker (Step 0) ──
  Widget _buildCategoryPicker() {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 4),
              Text('What would you like to share?', style: GoogleFonts.inter(color: subColor, fontSize: 15)),
              const SizedBox(height: 36),

              _buildCategoryCard(
                icon: Icons.photo_library_rounded,
                title: 'Post',
                subtitle: 'Share photos in a carousel',
                category: 'post',
                color: Colors.pinkAccent,
                accent: accent, isDark: isDark, textColor: textColor, subColor: subColor,
              ),
              const SizedBox(height: 14),
              _buildCategoryCard(
                icon: Icons.movie_creation_rounded,
                title: 'Reel',
                subtitle: 'Share a video or photo as a reel',
                category: 'reel',
                color: Colors.purpleAccent,
                accent: accent, isDark: isDark, textColor: textColor, subColor: subColor,
              ),
              const SizedBox(height: 14),
              _buildCategoryCard(
                icon: Icons.auto_awesome_rounded,
                title: 'Story',
                subtitle: 'Share a moment that disappears in 24h',
                category: 'story',
                color: Colors.orangeAccent,
                accent: accent, isDark: isDark, textColor: textColor, subColor: subColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required IconData icon, required String title, required String subtitle,
    required String category, required Color color,
    required Color accent, required bool isDark, required Color textColor, required Color subColor,
  }) {
    final sel = _category == category;
    return GestureDetector(
      onTap: () {
        setState(() {
          _category = category;
          _step = 1;
          _selectedMedia.clear();
          _videoCtrl?.dispose();
          _videoCtrl = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: sel ? color : Colors.transparent, width: 2),
          boxShadow: sel ? [BoxShadow(color: color.withAlpha(60), blurRadius: 16)] : null,
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withAlpha(40)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: textColor)),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: subColor)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: subColor, size: 16),
          ],
        ),
      ),
    );
  }

  // ── Media Selection (Step 1) ──
  Widget _buildMediaSelection() {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() { _step = 0; _selectedMedia.clear(); }),
                    child: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
                  ),
                  const Spacer(),
                  Text(
                    _category == 'post' ? 'New Post' : _category == 'reel' ? 'New Reel' : 'New Story',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _selectedMedia.isNotEmpty ? () => _goToEdit() : null,
                    child: Text('Next', style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: _selectedMedia.isNotEmpty ? accent : subColor,
                    )),
                  ),
                ],
              ),
            ),

            // Preview area
            Container(
              height: 280,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: _selectedMedia.isNotEmpty
                  ? _buildPreviewArea(isDark)
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_category == 'reel' ? Icons.videocam_rounded : Icons.add_a_photo_rounded,
                              color: accent, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            _category == 'post' ? 'Select photos' : _category == 'reel' ? 'Select a video' : 'Take a photo or video',
                            style: GoogleFonts.inter(color: subColor),
                          ),
                        ],
                      ),
                    ),
            ),

            // Selected count badge for posts
            if (_category == 'post' && _selectedMedia.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${_selectedMedia.length} selected — swipe to preview',
                  style: GoogleFonts.inter(color: accent, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),

            const SizedBox(height: 8),

            // Pick buttons
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    if (_category == 'post') ...[
                      _buildPickButton(Icons.photo_library_rounded, 'Select Photos', () => _pickMultipleImages(), accent, isDark, textColor),
                      const SizedBox(height: 10),
                      _buildPickButton(Icons.camera_alt_rounded, 'Take Photo', () => _pickSingle(ImageSource.camera, isVideo: false), accent, isDark, textColor),
                    ] else if (_category == 'reel') ...[
                      _buildPickButton(Icons.video_library_rounded, 'Choose Video', () => _pickSingle(ImageSource.gallery, isVideo: true), accent, isDark, textColor),
                      const SizedBox(height: 10),
                      _buildPickButton(Icons.photo_library_rounded, 'Choose Photo', () => _pickSingle(ImageSource.gallery, isVideo: false), accent, isDark, textColor),
                      const SizedBox(height: 10),
                      _buildPickButton(Icons.videocam_rounded, 'Record Video', () => _pickSingle(ImageSource.camera, isVideo: true), accent, isDark, textColor),
                    ] else ...[
                      _buildPickButton(Icons.photo_library_rounded, 'From Gallery', () => _pickSingle(ImageSource.gallery, isVideo: false), accent, isDark, textColor),
                      const SizedBox(height: 10),
                      _buildPickButton(Icons.videocam_rounded, 'Record / Take Photo', () => _pickSingle(ImageSource.camera, isVideo: false), accent, isDark, textColor),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewArea(bool isDark) {
    if (_selectedMedia.length == 1) {
      final file = File(_selectedMedia[0].path);
      final ext = _selectedMedia[0].name.toLowerCase();
      if (ext.endsWith('.mp4') || ext.endsWith('.mov') || ext.endsWith('.avi')) {
        // Video preview
        if (_videoCtrl != null && _videoCtrl!.value.isInitialized) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoCtrl!.value.size.width,
                height: _videoCtrl!.value.size.height,
                child: VideoPlayer(_videoCtrl!),
              ),
            ),
          );
        }
        return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
      }
      // Image preview
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(file, fit: BoxFit.cover, width: double.infinity),
      );
    }
    // Carousel preview for multi-select
    return PageView.builder(
      itemCount: _selectedMedia.length,
      onPageChanged: (i) => setState(() => _editIndex = i),
      itemBuilder: (ctx, i) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(_selectedMedia[i].path), fit: BoxFit.cover),
            ),
            Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54, borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${i + 1}/${_selectedMedia.length}',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPickButton(IconData icon, String label, VoidCallback onTap, Color accent, bool isDark, Color textColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withAlpha(40)),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withAlpha(30)),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 14),
            Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: accent.withAlpha(100), size: 16),
          ],
        ),
      ),
    );
  }

  // ── Edit / Preview (Step 2) — Stitch Design ──
  Widget _buildEditStep() {
    final accent = Theme.of(context).colorScheme.primary;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Full-screen media preview with filter ──
          Positioned.fill(child: _buildFilteredPreview()),

          // ── Text overlay (draggable) ──
          if (_overlayText.isNotEmpty)
            Positioned(
              left: _textX * screenW * 0.7,
              top: _textY * screenH * 0.6 + 60,
              child: GestureDetector(
                onPanUpdate: (d) {
                  setState(() {
                    _textX = (_textX + d.delta.dx / (screenW * 0.8)).clamp(0.0, 1.0);
                    _textY = (_textY + d.delta.dy / (screenH * 0.6)).clamp(0.0, 1.0);
                  });
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                      child: Text(_overlayText, style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                    Positioned(
                      top: -10, right: -10,
                      child: GestureDetector(
                        onTap: () => setState(() => _overlayText = ''),
                        child: Container(
                          width: 24, height: 24,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Stickers (draggable + deletable) ──
          ..._stickers.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            return Positioned(
              left: (s['x'] as double) * screenW * 0.7,
              top: (s['y'] as double) * screenH * 0.6 + 60,
              child: GestureDetector(
                onPanUpdate: (d) {
                  setState(() {
                    s['x'] = ((s['x'] as double) + d.delta.dx / (screenW * 0.8)).clamp(0.0, 1.0);
                    s['y'] = ((s['y'] as double) + d.delta.dy / (screenH * 0.6)).clamp(0.0, 1.0);
                  });
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Text(s['emoji'] as String, style: TextStyle(fontSize: (s['size'] as double?) ?? 36)),
                    Positioned(
                      top: -8, right: -8,
                      child: GestureDetector(
                        onTap: () => setState(() => _stickers.removeAt(i)),
                        child: Container(
                          width: 22, height: 22,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent),
                          child: const Icon(Icons.close, color: Colors.white, size: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // ── Play button overlay (center) ──
          if (_isVideoSelected() && _videoCtrl != null && _videoCtrl!.value.isInitialized)
            Center(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _videoCtrl!.value.isPlaying ? _videoCtrl!.pause() : _videoCtrl!.play();
                  });
                },
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(60),
                    border: Border.all(color: Colors.white.withAlpha(120), width: 2),
                  ),
                  child: Icon(
                    _videoCtrl!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white, size: 36,
                  ),
                ),
              ),
            ),

          // ── Top bar: back + Next pill ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16, right: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _step = 1),
                  child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _step = 3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text('Next', style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),

          // ── Right side vertical toolbar ──
          Positioned(
            right: 12,
            top: MediaQuery.of(context).padding.top + 70,
            child: Column(
              children: [
                _buildSideToolBtn(Icons.content_cut_rounded, 'TRIM', () => _showTrimPanel(), accent),
                const SizedBox(height: 16),
                _buildSideToolBtn(Icons.music_note_rounded, 'MUSIC', () => _showMusicPicker(), accent),
                const SizedBox(height: 16),
                _buildSideToolBtn(Icons.title_rounded, 'TEXT', () => _showTextDialog(), accent),
                const SizedBox(height: 16),
                _buildSideToolBtn(Icons.auto_awesome_rounded, 'FILTERS', () => _showFilterSheet(), accent),
                const SizedBox(height: 16),
                _buildSideToolBtn(Icons.emoji_emotions_outlined, 'STICKERS', () => _showStickerPicker(), accent),
              ],
            ),
          ),

          // ── Bottom: drafting info + timeline ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Music info bar
                  if (_musicEnabled && _musicName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.music_note, color: accent, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '♫ $_musicName • ${_musicEnd.toInt() - _musicStart.toInt()}s',
                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() { _musicEnabled = false; _musicPath = null; _musicName = ''; }),
                            child: const Icon(Icons.close, color: Colors.white54, size: 16),
                          ),
                        ],
                      ),
                    ),

                  // Drafting label
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.fiber_manual_record, color: accent, size: 10),
                        const SizedBox(width: 6),
                        Text(
                          'Drafting: "${_captionCtrl.text.isNotEmpty ? _captionCtrl.text.substring(0, _captionCtrl.text.length.clamp(0, 20)) : _category}" • ${_isVideoSelected() && _videoCtrl != null && _videoCtrl!.value.isInitialized ? '${_videoCtrl!.value.duration.inSeconds}s' : '0:15s'}',
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  // Timeline bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: _isVideoSelected() && _videoCtrl != null && _videoCtrl!.value.isInitialized
                                ? (_videoCtrl!.value.position.inMilliseconds / _videoCtrl!.value.duration.inMilliseconds.clamp(1, 999999))
                                : 0.5,
                            backgroundColor: Colors.white12,
                            color: accent,
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('0:00', style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
                            Text(
                              _isVideoSelected() && _videoCtrl != null && _videoCtrl!.value.isInitialized
                                  ? '0:${_videoCtrl!.value.duration.inSeconds.toString().padLeft(2, '0')}'
                                  : '0:15',
                              style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Multi-image page dots ──
          if (_selectedMedia.length > 1)
            Positioned(
              bottom: 100, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_selectedMedia.length, (i) => Container(
                  width: 8, height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: i == _editIndex ? accent : Colors.white38),
                )),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSideToolBtn(IconData icon, String label, VoidCallback onTap, Color accent) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withAlpha(150),
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  void _showTrimPanel() {
    if (!_isVideoSelected()) return;
    final accent = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Trim Video', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 16),
            RangeSlider(
              values: RangeValues(_trimStart, _trimEnd),
              min: 0, max: 1, activeColor: accent, inactiveColor: Colors.white12,
              onChanged: (v) => setState(() { _trimStart = v.start; _trimEnd = v.end; }),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Start: ${(_trimStart * 100).toInt()}%', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                Text('End: ${(_trimEnd * 100).toInt()}%', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showMusicPicker() {
    final accent = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, scrollCtrl) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text('Add Music', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 6),
                Text('Pick a song from your device', style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 20),

                // Pick from device button
                GestureDetector(
                  onTap: () async {
                    // Simulate music pick — in production, use file_picker or on_audio_query
                    setSheetState(() {
                      _musicPath = '/device/music/sample.mp3';
                      _musicName = 'My Favorite Song';
                      _musicEnabled = true;
                      _musicStart = 0;
                      _musicEnd = 15;
                    });
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accent.withAlpha(20),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accent.withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withAlpha(40)),
                          child: Icon(Icons.folder_open_rounded, color: accent, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Browse Device Music', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                            Text('Select from your music library', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                          ],
                        )),
                        Icon(Icons.arrow_forward_ios, color: accent, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 15-sec music timeline (shown when music selected)
                if (_musicEnabled) ...[
                  Text('Crop Music — 15 Second Clip', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(_musicName, style: GoogleFonts.inter(color: accent, fontSize: 13)),
                  const SizedBox(height: 12),

                  // Waveform-style timeline
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withAlpha(10),
                    ),
                    child: Stack(
                      children: [
                        // Fake waveform bars
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: List.generate(50, (i) {
                            final h = 8.0 + (i % 7) * 4.0 + (i % 3) * 3.0;
                            return Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 0.5),
                                height: h,
                                decoration: BoxDecoration(
                                  color: (i >= (_musicStart / 60 * 50).toInt() && i <= (_musicEnd / 60 * 50).toInt())
                                      ? accent.withAlpha(180)
                                      : Colors.white12,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Time range slider
                  RangeSlider(
                    values: RangeValues(_musicStart, _musicEnd),
                    min: 0, max: 60, // assume 60s track
                    divisions: 60,
                    activeColor: accent,
                    inactiveColor: Colors.white12,
                    onChanged: (v) {
                      // Enforce 15-sec max clip
                      double start = v.start;
                      double end = v.end;
                      if (end - start > 15) {
                        end = start + 15;
                      }
                      if (end > 60) { end = 60; start = 45; }
                      setSheetState(() { _musicStart = start; _musicEnd = end; });
                      setState(() {});
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_musicStart.toInt()}s', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                      Text('${(_musicEnd - _musicStart).toInt()}s clip', style: GoogleFonts.inter(color: accent, fontWeight: FontWeight.w600, fontSize: 12)),
                      Text('${_musicEnd.toInt()}s', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Use This Clip', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    final accent = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Filters', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 16),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                itemBuilder: (ctx, i) {
                  final f = _filters[i];
                  final sel = _selectedFilter == f;
                  return GestureDetector(
                    onTap: () { setState(() => _selectedFilter = f); Navigator.pop(ctx); },
                    child: Container(
                      width: 68, margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: sel ? accent : Colors.white12, width: 2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFilterThumbnail(f),
                          const SizedBox(height: 6),
                          Text(f[0].toUpperCase() + f.substring(1),
                            style: GoogleFonts.inter(fontSize: 10, color: sel ? accent : Colors.white54, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredPreview() {
    if (_selectedMedia.isEmpty) return const SizedBox();

    Widget preview;
    if (_selectedMedia.length > 1) {
      preview = PageView.builder(
        itemCount: _selectedMedia.length,
        onPageChanged: (i) => setState(() => _editIndex = i),
        itemBuilder: (ctx, i) => Image.file(File(_selectedMedia[i].path), fit: BoxFit.cover),
      );
    } else if (_isVideoSelected() && _videoCtrl != null && _videoCtrl!.value.isInitialized) {
      preview = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _videoCtrl!.value.size.width,
          height: _videoCtrl!.value.size.height,
          child: VideoPlayer(_videoCtrl!),
        ),
      );
    } else {
      preview = Image.file(File(_selectedMedia[0].path), fit: BoxFit.cover, width: double.infinity);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColorFiltered(
        colorFilter: _getColorFilter(),
        child: preview,
      ),
    );
  }

  ColorFilter _getColorFilter() {
    switch (_selectedFilter) {
      case 'warm':
        return const ColorFilter.matrix([1.2, 0, 0, 0, 20, 0, 1.1, 0, 0, 10, 0, 0, 0.9, 0, 0, 0, 0, 0, 1, 0]);
      case 'cool':
        return const ColorFilter.matrix([0.9, 0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 0, 1.2, 0, 20, 0, 0, 0, 1, 0]);
      case 'sepia':
        return const ColorFilter.matrix([0.393, 0.769, 0.189, 0, 0, 0.349, 0.686, 0.168, 0, 0, 0.272, 0.534, 0.131, 0, 0, 0, 0, 0, 1, 0]);
      case 'grayscale':
        return const ColorFilter.matrix([0.299, 0.587, 0.114, 0, 0, 0.299, 0.587, 0.114, 0, 0, 0.299, 0.587, 0.114, 0, 0, 0, 0, 0, 1, 0]);
      case 'vibrant':
        return const ColorFilter.matrix([1.5, 0, 0, 0, -30, 0, 1.5, 0, 0, -30, 0, 0, 1.5, 0, -30, 0, 0, 0, 1, 0]);
      case 'fade':
        return const ColorFilter.matrix([1, 0, 0, 0, 40, 0, 1, 0, 0, 40, 0, 0, 1, 0, 40, 0, 0, 0, 0.9, 0]);
      case 'noir':
        return const ColorFilter.matrix([0.3, 0.6, 0.1, 0, -20, 0.3, 0.6, 0.1, 0, -20, 0.3, 0.6, 0.1, 0, -20, 0, 0, 0, 1, 0]);
      default:
        return const ColorFilter.mode(Colors.transparent, BlendMode.multiply);
    }
  }

  Widget _buildFilterThumbnail(String filter) {
    if (_selectedMedia.isEmpty) {
      return Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(6)));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 36, height: 36,
        child: ColorFiltered(
          colorFilter: _getColorFilterForName(filter),
          child: Image.file(File(_selectedMedia[_editIndex.clamp(0, _selectedMedia.length - 1)].path), fit: BoxFit.cover),
        ),
      ),
    );
  }

  ColorFilter _getColorFilterForName(String name) {
    final saved = _selectedFilter;
    _selectedFilter = name;
    final f = _getColorFilter();
    _selectedFilter = saved;
    return f;
  }

  Widget _buildToolButton(IconData icon, String label, VoidCallback onTap, Color accent, Color subColor) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 24),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: subColor)),
        ],
      ),
    );
  }

  void _showTextDialog() {
    final ctrl = TextEditingController(text: _overlayText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Text'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Type your text...')),
        actions: [
          TextButton(onPressed: () { setState(() => _overlayText = ''); Navigator.pop(ctx); }, child: const Text('Remove')),
          TextButton(onPressed: () { setState(() => _overlayText = ctrl.text); Navigator.pop(ctx); }, child: const Text('Done')),
        ],
      ),
    );
  }

  void _showStickerPicker() {
    final emojis = ['😀', '🔥', '❤️', '😎', '🤩', '✨', '💯', '🎵', '🎬', '🌟', '💪', '🙌', '👏', '🎉', '🦋', '🌈', '💎', '🏆', '🎯', '🌺'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add Sticker', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: emojis.map((e) => GestureDetector(
                onTap: () {
                  setState(() => _stickers.add({'emoji': e, 'x': 0.4, 'y': 0.4, 'size': 36.0}));
                  Navigator.pop(ctx);
                },
                child: Text(e, style: const TextStyle(fontSize: 32)),
              )).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Post Details (Step 3) ──
  Widget _buildPostDetails() {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _step = 2),
                    child: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
                  ),
                  const Spacer(),
                  Text('Post Details', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  const Spacer(),
                  const SizedBox(width: 22),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 12),
                  // Thumbnail + Caption row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 80, height: 100,
                          child: _selectedMedia.isNotEmpty
                              ? (_isVideoSelected() && _videoCtrl != null && _videoCtrl!.value.isInitialized
                                  ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: _videoCtrl!.value.size.width, height: _videoCtrl!.value.size.height, child: VideoPlayer(_videoCtrl!)))
                                  : Image.file(File(_selectedMedia[0].path), fit: BoxFit.cover))
                              : Container(color: cardColor),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: _captionCtrl,
                          maxLines: 4,
                          style: TextStyle(color: textColor, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Write a caption or add\nhashtags... #pistagram',
                            hintStyle: TextStyle(color: subColor, fontSize: 14),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Creator Rewards banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(colors: [accent.withAlpha(40), accent.withAlpha(15)]),
                      border: Border.all(color: accent.withAlpha(50)),
                    ),
                    child: Row(
                      children: [
                        Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withAlpha(50)),
                          child: Icon(Icons.stars_rounded, color: accent, size: 22)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Creator Rewards Active', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: textColor)),
                          Text('Earn up to 50 PISTA tokens per view', style: GoogleFonts.inter(fontSize: 12, color: subColor)),
                        ])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Privacy & Comments
                  Text('PRIVACY & COMMENTS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: subColor, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardColor, borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    child: Column(
                      children: [
                        Row(children: [
                          Icon(Icons.public_rounded, color: textColor.withAlpha(150), size: 22),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Who can see this', style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14, color: textColor)),
                            Text(_visibilityLabel(), style: GoogleFonts.inter(fontSize: 12, color: subColor)),
                          ])),
                          DropdownButton<String>(
                            value: _visibility,
                            underline: const SizedBox(),
                            dropdownColor: cardColor,
                            style: GoogleFonts.inter(color: accent, fontWeight: FontWeight.w600, fontSize: 14),
                            items: const [
                              DropdownMenuItem(value: 'public', child: Text('Public')),
                              DropdownMenuItem(value: 'followers', child: Text('Followers')),
                              DropdownMenuItem(value: 'private', child: Text('Private')),
                            ],
                            onChanged: (v) => setState(() => _visibility = v ?? 'public'),
                          ),
                        ]),
                        Divider(color: isDark ? Colors.white10 : Colors.black12, height: 24),
                        Row(children: [
                          Icon(Icons.chat_bubble_rounded, color: textColor.withAlpha(150), size: 22),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Allow Comments', style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14, color: textColor)),
                            Text('Let others interact with your post', style: GoogleFonts.inter(fontSize: 12, color: subColor)),
                          ])),
                          Switch(value: _allowComments, activeColor: accent, onChanged: (v) => setState(() => _allowComments = v)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Bottom: Drafts + Post button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
                border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DraftsScreen()));
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text('Drafts', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _saveDraft,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text('Save', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _upload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: Text(
                        _category == 'story' ? 'Share Story' : _category == 'reel' ? 'Post Reel' : 'Post',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Uploading View ──
  Widget _buildUploadingView() {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 100, height: 100, child: CircularProgressIndicator(
              value: _uploadProgress, color: accent, strokeWidth: 6, backgroundColor: accent.withAlpha(30))),
            const SizedBox(height: 20),
            Text('${(_uploadProgress * 100).toInt()}%', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: accent)),
            const SizedBox(height: 8),
            Text('Uploading your ${_category}...', style: GoogleFonts.inter(color: isDark ? Colors.white54 : Colors.black54)),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──
  bool _isVideoSelected() {
    if (_selectedMedia.isEmpty) return false;
    final name = _selectedMedia[0].name.toLowerCase();
    return name.endsWith('.mp4') || name.endsWith('.mov') || name.endsWith('.avi') || name.endsWith('.webm');
  }

  Future<void> _pickMultipleImages() async {
    final images = await _imagePicker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedMedia.clear();
        _selectedMedia.addAll(images);
        _editIndex = 0;
      });
    }
  }

  Future<void> _pickSingle(ImageSource source, {required bool isVideo}) async {
    XFile? file;
    if (isVideo) {
      file = await _imagePicker.pickVideo(source: source, maxDuration: const Duration(minutes: 5));
    } else {
      file = await _imagePicker.pickImage(source: source, imageQuality: 85);
    }
    if (file != null) {
      setState(() {
        _selectedMedia.clear();
        _selectedMedia.add(file!);
        _editIndex = 0;
      });
      if (isVideo) {
        _videoCtrl?.dispose();
        _videoCtrl = VideoPlayerController.file(File(file.path))
          ..initialize().then((_) { if (mounted) setState(() {}); });
      }
    }
  }

  void _goToEdit() {
    setState(() => _step = 2);
  }

  String _visibilityLabel() {
    switch (_visibility) {
      case 'public': return 'Public — visible in Discovery';
      case 'followers': return 'Followers only';
      case 'private': return 'Only you can see';
      default: return '';
    }
  }

  // ── Upload ──
  Future<void> _upload() async {
    if (_selectedMedia.isEmpty) return;
    setState(() { _uploading = true; _uploadProgress = 0.05; });

    try {
      final uid = _auth.currentUser?.uid ?? '';

      if (_category == 'post') {
        await _uploadPost(uid);
      } else if (_category == 'reel') {
        await _uploadReel(uid);
      } else {
        await _uploadStory(uid);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('🎉 ${_category[0].toUpperCase()}${_category.substring(1)} shared!', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        _resetState();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating,
        ));
        setState(() { _uploading = false; _uploadProgress = 0; });
      }
    }
  }

  Future<void> _uploadPost(String uid) async {
    final urls = <String>[];
    final ids = <String>[];
    for (var i = 0; i < _selectedMedia.length; i++) {
      setState(() => _uploadProgress = 0.1 + (0.7 * i / _selectedMedia.length));
      final result = await _cloudinary.uploadFile(File(_selectedMedia[i].path), folder: 'posts');
      urls.add(result['url'] ?? '');
      ids.add(result['publicId'] ?? '');
    }
    setState(() => _uploadProgress = 0.85);

    final hashtags = RegExp(r'#(\w+)').allMatches(_captionCtrl.text).map((m) => m.group(1)!.toLowerCase()).toList();
    final post = PostModel(
      postId: const Uuid().v4(),
      creatorUid: uid,
      mediaUrls: urls,
      cloudinaryIds: ids,
      mediaType: urls.length > 1 ? 'mixed' : 'image',
      caption: _captionCtrl.text.trim(),
      hashtags: hashtags,
      visibility: _visibility,
      allowComments: _allowComments,
    );
    await _firestore.createPost(post);
    setState(() => _uploadProgress = 1.0);
  }

  Future<void> _uploadReel(String uid) async {
    setState(() => _uploadProgress = 0.2);
    final file = File(_selectedMedia[0].path);
    Map<String, String> result;
    if (_isVideoSelected()) {
      result = await _cloudinary.uploadVideo(file);
    } else {
      result = await _cloudinary.uploadFile(file, folder: 'reels');
    }
    setState(() => _uploadProgress = 0.7);

    final videoUrl = result['url'] ?? '';
    final thumbnailUrl = _isVideoSelected()
        ? videoUrl.replaceAll('/video/upload/', '/video/upload/so_0,w_400,h_600,c_fill/').replaceAll('.mp4', '.jpg').replaceAll('.mov', '.jpg')
        : videoUrl;

    final hashtags = RegExp(r'#(\w+)').allMatches(_captionCtrl.text).map((m) => m.group(1)!.toLowerCase()).toList();
    final reel = ReelModel(
      reelId: const Uuid().v4(),
      creatorUid: uid,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      cloudinaryPublicId: result['publicId'] ?? '',
      caption: _captionCtrl.text.trim(),
      hashtags: hashtags,
      visibility: _visibility,
    );
    await _firestore.createReel(reel);
    setState(() => _uploadProgress = 1.0);
  }

  Future<void> _uploadStory(String uid) async {
    setState(() => _uploadProgress = 0.2);
    final file = File(_selectedMedia[0].path);
    final isVideo = _isVideoSelected();
    Map<String, String> result;
    if (isVideo) {
      result = await _cloudinary.uploadVideo(file);
    } else {
      result = await _cloudinary.uploadFile(file, folder: 'stories');
    }
    setState(() => _uploadProgress = 0.8);

    final story = StoryModel(
      storyId: const Uuid().v4(),
      creatorUid: uid,
      mediaUrl: result['url'] ?? '',
      mediaType: isVideo ? 'video' : 'image',
      cloudinaryId: result['publicId'] ?? '',
      text: _overlayText,
      textX: _textX, textY: _textY,
      filter: _selectedFilter,
      stickers: List<Map<String, dynamic>>.from(_stickers),
    );
    await _firestore.createStory(story);
    setState(() => _uploadProgress = 1.0);
  }

  void _resetState() {
    setState(() {
      _step = 0;
      _selectedMedia.clear();
      _videoCtrl?.dispose();
      _videoCtrl = null;
      _captionCtrl.clear();
      _uploading = false;
      _uploadProgress = 0;
      _visibility = 'public';
      _allowComments = true;
      _selectedFilter = 'none';
      _overlayText = '';
      _stickers.clear();
      _trimStart = 0;
      _trimEnd = 1.0;
      _musicPath = null;
      _musicName = '';
      _musicStart = 0;
      _musicEnd = 15;
      _musicEnabled = false;
    });
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_uploading) return _buildUploadingView();
    switch (_step) {
      case 0: return _buildCategoryPicker();
      case 1: return _buildMediaSelection();
      case 2: return _buildEditStep();
      case 3: return _buildPostDetails();
      default: return _buildCategoryPicker();
    }
  }
}

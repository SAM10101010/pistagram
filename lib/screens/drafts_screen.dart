import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/draft_service.dart';
import '../utils/animations.dart';
import 'upload_screen.dart';

class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key});

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  final _draftService = DraftService();
  List<DraftModel> _drafts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    _drafts = await _draftService.getDrafts();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteDraft(DraftModel draft) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Draft'),
        content: const Text('This draft will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _draftService.deleteDraft(draft.id);
      _loadDrafts();
    }
  }

  void _openDraft(DraftModel draft) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => UploadScreen(draft: draft)),
    );
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
        backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA), scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Drafts', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
        centerTitle: true,
      ),
      body: _loading
          ? ListView.builder(
  padding: const EdgeInsets.all(12),
  itemCount: 4,
  itemBuilder: (_, __) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(children: [
      const ShimmerLoading(width: 64, height: 64, borderRadius: 10),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        ShimmerLoading(width: 60, height: 16, borderRadius: 8),
        SizedBox(height: 8),
        ShimmerLoading(width: 140, height: 14, borderRadius: 6),
        SizedBox(height: 6),
        ShimmerLoading(width: 80, height: 10, borderRadius: 6),
      ])),
    ]),
  ),
)
          : _drafts.isEmpty
              ? Center(
                  child: Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Container(
      width: 80, height: 80,
      decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[100]),
      child: Icon(Icons.drafts_outlined, size: 36, color: subColor),
    ),
    const SizedBox(height: 20),
    Text('No drafts saved', style: GoogleFonts.inter(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
    const SizedBox(height: 4),
    Text('Create a post and save it as a draft', style: GoogleFonts.inter(color: subColor, fontSize: 13)),
  ],
),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _drafts.length,
                  itemBuilder: (ctx, i) {
                    final draft = _drafts[i];
                    return _buildDraftCard(draft, accent, isDark, textColor, subColor);
                  },
                ),
    );
  }

  Widget _buildDraftCard(DraftModel draft, Color accent, bool isDark, Color textColor, Color subColor) {
    final hasImage = draft.mediaPaths.isNotEmpty && File(draft.mediaPaths[0]).existsSync();
    final icon = draft.category == 'reel'
        ? Icons.video_library_rounded
        : draft.category == 'story'
            ? Icons.amp_stories_rounded
            : Icons.photo_library_rounded;

    return Card(
      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () => _openDraft(draft),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64, height: 64,
                  child: hasImage
                      ? Image.file(File(draft.mediaPaths[0]), fit: BoxFit.cover)
                      : Container(
                          color: isDark ? Colors.white10 : Colors.grey[200],
                          child: Icon(icon, color: accent, size: 28),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: accent.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            draft.category.toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: accent),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          draft.visibility,
                          style: GoogleFonts.inter(fontSize: 10, color: subColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      draft.caption.isNotEmpty ? draft.caption : 'No caption',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeago.format(draft.createdAt),
                      style: GoogleFonts.inter(fontSize: 11, color: subColor),
                    ),
                  ],
                ),
              ),
              // Delete button
              IconButton(
                onPressed: () => _deleteDraft(draft),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

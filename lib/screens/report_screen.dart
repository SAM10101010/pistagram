import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/moderation_service.dart';

class ReportScreen extends StatefulWidget {
  final String targetType; // 'reel', 'user', 'comment'
  final String targetId;

  const ReportScreen({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _auth = AuthService();
  final _moderation = ModerationService();
  final _additionalController = TextEditingController();

  String _selectedReason = '';
  bool _submitting = false;

  final List<String> _reasons = [
    'Spam',
    'Nudity or Sexual Content',
    'Violence or Threats',
    'Harassment or Bullying',
    'Hate Speech',
    'False Information',
    'Other',
  ];

  @override
  void dispose() {
    _additionalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a reason'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final uid = _auth.currentUser?.uid ?? '';
      String reason = _selectedReason;
      if (_additionalController.text.trim().isNotEmpty) {
        reason += ': ${_additionalController.text.trim()}';
      }

      await _moderation.reportContent(
        reporterUid: uid,
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: reason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Report submitted. Thank you!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to submit report'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Report ${widget.targetType[0].toUpperCase()}${widget.targetType.substring(1)}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: textColor), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent.withAlpha(15),
              ),
              child: const Icon(Icons.flag_rounded, color: Colors.redAccent, size: 32),
            ),
            const SizedBox(height: 20),
            Text('Why are you reporting this?', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
            const SizedBox(height: 6),
            Text('Select a reason that best describes the issue.', style: GoogleFonts.inter(fontSize: 13, color: subColor)),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
  color: cardColor,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(10)),
),
              child: Column(
                children: _reasons.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final reason = entry.value;
                  return Column(
                    children: [
                      RadioListTile<String>(
                        value: reason,
                        groupValue: _selectedReason,
                        onChanged: (val) => setState(() => _selectedReason = val ?? ''),
                        activeColor: accent,
                        title: Text(reason, style: GoogleFonts.inter(fontSize: 14, color: textColor)),
                      ),
                      if (idx < _reasons.length - 1) Divider(height: 1, color: subColor.withAlpha(30)),
                    ],
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),
            Text('Additional details (optional)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
            const SizedBox(height: 8),
            TextField(
              controller: _additionalController,
              maxLines: 3,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Provide more context...',
                hintStyle: TextStyle(color: subColor),
                filled: true,
                fillColor: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: accent, width: 1.5)),
              ),
            ),

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(colors: [Colors.redAccent, Color(0xFFE53935)]),
                  boxShadow: [BoxShadow(color: Colors.redAccent.withAlpha(60), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text('Submit Report', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

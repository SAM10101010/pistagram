import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/warning_model.dart';
import '../services/warning_service.dart';
import '../services/appeal_service.dart';

class WarningsScreen extends StatefulWidget {
  const WarningsScreen({super.key});

  @override
  State<WarningsScreen> createState() => _WarningsScreenState();
}

class _WarningsScreenState extends State<WarningsScreen> {
  final _warningService = WarningService();
  final _appealService = AppealService();
  List<WarningModel> _warnings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final warnings = await _warningService.getAllWarnings(uid);
      if (mounted) {
        setState(() {
          _warnings = warnings;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading warnings: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _acknowledgeWarning(WarningModel warning) async {
    await _warningService.acknowledgeWarning(warning.warningId);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Warning acknowledged', style: GoogleFonts.inter()),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _submitAppeal(WarningModel warning) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Appeal Warning'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Explain why you think this warning should be removed...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit Appeal'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonCtrl.text.trim().isNotEmpty) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final exists = await _appealService.hasExistingAppeal(warning.warningId);
      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You already have a pending appeal for this warning',
                  style: GoogleFonts.inter()),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      await _appealService.submitAppeal(
        userId: uid,
        appealType: 'warning',
        relatedId: warning.warningId,
        reason: reasonCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Appeal submitted successfully',
                style: GoogleFonts.inter()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: Text('Warnings', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48,
                            color: isDark ? Colors.white24 : Colors.black26),
                        const SizedBox(height: 12),
                        Text('Could not load warnings',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white54 : Colors.black54,
                                fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Please try again later',
                            style: GoogleFonts.inter(
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontSize: 13)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _warnings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 64,
                          color: isDark ? Colors.white24 : Colors.black26),
                      const SizedBox(height: 12),
                      Text('No warnings',
                          style: GoogleFonts.inter(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Your account is in good standing',
                          style: GoogleFonts.inter(
                              color: isDark ? Colors.white24 : Colors.black26,
                              fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _warnings.length,
                    itemBuilder: (context, index) =>
                        _buildWarningCard(_warnings[index], isDark, textColor),
                  ),
                ),
    );
  }

  Widget _buildWarningCard(
      WarningModel warning, bool isDark, Color textColor) {
    final levelColor = _levelColor(warning.level);
    final isActive = warning.status == 'active';

    return Card(
      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isActive
            ? BorderSide(color: levelColor.withValues(alpha:0.3))
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha:0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Level ${warning.level} — ${warning.levelLabel}',
                    style: GoogleFonts.inter(
                      color: levelColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(warning.status).withValues(alpha:0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    warning.status.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: _statusColor(warning.status),
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Type
            if (warning.type.isNotEmpty)
              Text(
                warning.type.replaceAll('_', ' ').toUpperCase(),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  fontSize: 14,
                ),
              ),
            if (warning.title.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(warning.title,
                  style: GoogleFonts.inter(
                      color: textColor, fontWeight: FontWeight.w500)),
            ],
            if (warning.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(warning.description,
                  style: GoogleFonts.inter(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 13)),
            ],
            const SizedBox(height: 8),

            // Date
            Text(
              _formatDate(warning.createdAt),
              style: GoogleFonts.inter(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 11),
            ),

            // Actions
            if (isActive && !warning.acknowledgedByUser) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _acknowledgeWarning(warning),
                      child: const Text('Acknowledge'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _submitAppeal(warning),
                      child: const Text('Appeal'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _levelColor(int level) {
    switch (level) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.red;
      case 'acknowledged':
        return Colors.blue;
      case 'revoked':
        return Colors.green;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

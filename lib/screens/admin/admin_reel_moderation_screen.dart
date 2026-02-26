import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/moderation_service.dart';
import '../../models/report_model.dart';

class AdminReelModerationScreen extends StatefulWidget {
  const AdminReelModerationScreen({super.key});

  @override
  State<AdminReelModerationScreen> createState() => _AdminReelModerationScreenState();
}

class _AdminReelModerationScreenState extends State<AdminReelModerationScreen> {
  final _moderation = ModerationService();
  List<ReportModel> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final reports = await _moderation.getPendingReports();
      if (mounted) {
        setState(() {
          _reports = reports.where((r) => r.targetType == 'reel').toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reports: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeContent(ReportModel report) async {
    await _moderation.removeContent(report.targetId);
    await _moderation.resolveReport(report.id, 'removed');
    if (mounted) {
      setState(() => _reports.remove(report));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Content removed'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      );
    }
  }

  Future<void> _dismiss(ReportModel report) async {
    await _moderation.resolveReport(report.id, 'dismissed');
    if (mounted) {
      setState(() => _reports.remove(report));
    }
  }

  Future<void> _banCreator(ReportModel report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ban Creator'),
        content: Text('Permanently ban the creator of this reel (${report.targetId})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ban', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed == true) {
      await _moderation.removeContent(report.targetId);
      await _moderation.resolveReport(report.id, 'banned');
      if (mounted) {
        setState(() => _reports.remove(report));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Creator banned & content removed'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        );
      }
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
        title: Text('Reel Moderation', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: textColor), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : _reports.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                      const SizedBox(height: 12),
                      Text('No pending reports', style: GoogleFonts.inter(color: subColor, fontSize: 15)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _reports.length,
                  itemBuilder: (ctx, i) {
                    final report = _reports[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.report, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Reel: ${report.targetId.length > 12 ? '${report.targetId.substring(0, 12)}...' : report.targetId}',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Reason: ${report.reason}', style: GoogleFonts.inter(fontSize: 13, color: subColor)),
                          Text('Reporter: ${report.reporterUid.length > 12 ? '${report.reporterUid.substring(0, 12)}...' : report.reporterUid}', style: GoogleFonts.inter(fontSize: 12, color: subColor)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _dismiss(report),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: subColor.withAlpha(80)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text('Dismiss', style: GoogleFonts.inter(fontSize: 12, color: subColor)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _removeContent(report),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text('Remove', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _banCreator(report),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text('Ban', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

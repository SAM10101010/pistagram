import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/prediction_service.dart';
import '../services/auth_service.dart';
import '../utils/animations.dart';

class PredictionsScreen extends StatefulWidget {
  const PredictionsScreen({super.key});

  @override
  State<PredictionsScreen> createState() => _PredictionsScreenState();
}

class _PredictionsScreenState extends State<PredictionsScreen>
    with SingleTickerProviderStateMixin {
  final PredictionService _predictionService = PredictionService();
  final AuthService _auth = AuthService();
  late TabController _tabController;

  List<Map<String, dynamic>> _active = [];
  List<Map<String, dynamic>> _resolved = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = _auth.currentUser?.uid ?? '';
    final all = await _predictionService.getAllPredictions(uid);
    _active = all.where((p) => p['resolved'] != true).toList();
    _resolved = all.where((p) => p['resolved'] == true).toList();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

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
          'Predictions',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: accent.withAlpha(25),
          ),
          dividerColor: Colors.transparent,
          labelColor: accent,
          unselectedLabelColor: subColor,
          labelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          tabs: [
            Tab(text: 'Active (${_active.length})'),
            Tab(text: 'Resolved (${_resolved.length})'),
          ],
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: accent, strokeWidth: 2),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPredictionList(
                  _active,
                  false,
                  accent,
                  isDark,
                  textColor,
                  subColor,
                ),
                _buildPredictionList(
                  _resolved,
                  true,
                  accent,
                  isDark,
                  textColor,
                  subColor,
                ),
              ],
            ),
    );
  }

  Widget _buildPredictionList(
    List<Map<String, dynamic>> predictions,
    bool isResolved,
    Color accent,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    if (predictions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology_outlined, size: 48, color: subColor),
            const SizedBox(height: 12),
            Text(
              isResolved ? 'No resolved predictions' : 'No active predictions',
              style: GoogleFonts.inter(color: subColor),
            ),
            Text(
              isResolved
                  ? 'Your resolved predictions will appear here'
                  : 'Watch reels to make predictions!',
              style: GoogleFonts.inter(color: subColor, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: predictions.length,
      itemBuilder: (ctx, i) {
        final prediction = predictions[i];
        final type =
            PredictionService.predictionTypes[prediction['predictionType']];
        final isCorrect = prediction['correct'] == true;
        final bonus = prediction['bonusAwarded'] ?? 0;
        final createdAt =
            (prediction['createdAt'] as dynamic)?.toDate() ?? DateTime.now();

        return FadeInSlide(
          delay: i * 50,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isResolved
                    ? (isCorrect
                          ? Colors.green.withAlpha(60)
                          : Colors.red.withAlpha(60))
                    : (isDark
                          ? Colors.white.withAlpha(10)
                          : Colors.black.withAlpha(10)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isResolved
                            ? (isCorrect
                                  ? Colors.green.withAlpha(20)
                                  : Colors.red.withAlpha(20))
                            : accent.withAlpha(20),
                      ),
                      child: Icon(
                        isResolved
                            ? (isCorrect
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded)
                            : Icons.psychology_rounded,
                        color: isResolved
                            ? (isCorrect ? Colors.green : Colors.red)
                            : accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type?['label'] ?? 'Prediction',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: textColor,
                            ),
                          ),
                          Text(
                            'Predicted: ${prediction['prediction'] == true ? "Yes" : "No"}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: subColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isResolved && isCorrect)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+$bonus pts',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.green,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      timeago.format(createdAt),
                      style: GoogleFonts.inter(fontSize: 11, color: subColor),
                    ),
                    if (!isResolved)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withAlpha(15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Resolves in 7 days',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ),
                    if (isResolved)
                      Text(
                        isCorrect ? 'Correct!' : 'Wrong',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isCorrect ? Colors.green : Colors.red,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

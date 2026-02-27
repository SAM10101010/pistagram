import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/campaign_model.dart';
import '../services/campaign_service.dart';
import '../services/auth_service.dart';
import '../utils/animations.dart';

class CampaignDetailScreen extends StatefulWidget {
  final CampaignModel campaign;
  const CampaignDetailScreen({super.key, required this.campaign});

  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  final CampaignService _campaignService = CampaignService();
  final AuthService _auth = AuthService();
  CampaignProgressModel? _progress;
  bool _loading = true;
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final uid = _auth.currentUser?.uid ?? '';
    _progress = await _campaignService.getUserProgress(
      uid,
      widget.campaign.campaignId,
    );
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _claimReward() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    final uid = _auth.currentUser?.uid ?? '';
    final success = await _campaignService.claimReward(
      uid,
      widget.campaign.campaignId,
    );
    if (success) {
      await _loadProgress();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Claimed ${widget.campaign.rewardPoints} points!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    if (mounted) setState(() => _claiming = false);
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final campaign = widget.campaign;

    final currentProgress = _progress?.currentProgress ?? 0;
    final progressValue = currentProgress / campaign.conditionValue;
    final isCompleted = _progress?.completed ?? false;
    final isRewardClaimed = _progress?.rewardClaimed ?? false;
    final timeRemaining = campaign.timeRemaining;

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
          'Campaign',
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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Campaign header
                FadeInSlide(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        colors: [accent, accent.withAlpha(160)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withAlpha(50),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (campaign.imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              campaign.imageUrl,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                        if (campaign.imageUrl.isNotEmpty)
                          const SizedBox(height: 16),
                        Text(
                          campaign.title,
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (campaign.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            campaign.description,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 16),
                        // Time remaining
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                timeRemaining.isNegative
                                    ? 'Ended'
                                    : '${_formatDuration(timeRemaining)} left',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Progress card
                FadeInSlide(
                  delay: 100,
                  child: Container(
                    padding: const EdgeInsets.all(20),
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
                              '$currentProgress / ${campaign.conditionValue}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progressValue.clamp(0.0, 1.0),
                            backgroundColor: isDark
                                ? Colors.white.withAlpha(15)
                                : Colors.grey.withAlpha(40),
                            valueColor: AlwaysStoppedAnimation(
                              isCompleted ? Colors.green : accent,
                            ),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isCompleted
                              ? (isRewardClaimed
                                    ? 'Reward claimed!'
                                    : 'Completed! Claim your reward.')
                              : '${((progressValue.clamp(0.0, 1.0)) * 100).toInt()}% complete',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isCompleted ? Colors.green : subColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Reward info
                FadeInSlide(
                  delay: 200,
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
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFFD700).withAlpha(30),
                          ),
                          child: const Icon(
                            Icons.stars_rounded,
                            color: Color(0xFFFFD700),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reward',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                '${campaign.rewardPoints} bonus points',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: subColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withAlpha(15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            campaign.rewardType,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Condition info
                FadeInSlide(
                  delay: 300,
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
                    child: Row(
                      children: [
                        Icon(Icons.flag_rounded, color: accent, size: 24),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _getConditionText(
                              campaign.conditionType,
                              campaign.conditionValue,
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Claim button
                if (isCompleted && !isRewardClaimed)
                  FadeInSlide(
                    delay: 400,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _claiming ? null : _claimReward,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 4,
                        ),
                        child: _claiming
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                'Claim ${campaign.rewardPoints} Points',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _getConditionText(String type, int value) {
    switch (type) {
      case 'watch_count':
        return 'Watch $value reels to complete this campaign';
      case 'streak_days':
        return 'Maintain a $value-day watch streak';
      case 'earn_points':
        return 'Earn $value points';
      case 'like_count':
        return 'Like $value reels';
      default:
        return 'Complete the challenge to earn rewards';
    }
  }
}

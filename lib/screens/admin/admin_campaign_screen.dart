import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../models/campaign_model.dart';
import '../../services/campaign_service.dart';
import '../../utils/animations.dart';

class AdminCampaignScreen extends StatefulWidget {
  const AdminCampaignScreen({super.key});

  @override
  State<AdminCampaignScreen> createState() => _AdminCampaignScreenState();
}

class _AdminCampaignScreenState extends State<AdminCampaignScreen> {
  final CampaignService _campaignService = CampaignService();
  List<CampaignModel> _campaigns = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _campaigns = await _campaignService.getAllCampaigns();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _showCreateDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final valueCtrl = TextEditingController(text: '20');
    final rewardCtrl = TextEditingController(text: '50');
    String conditionType = 'watch_count';
    int durationDays = 7;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final accent = Theme.of(ctx).colorScheme.primary;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black87;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Create Campaign',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField('Title', titleCtrl, isDark, textColor),
                    const SizedBox(height: 12),
                    _buildTextField(
                      'Description',
                      descCtrl,
                      isDark,
                      textColor,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Condition Type',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButton<String>(
                      value: conditionType,
                      isExpanded: true,
                      dropdownColor: isDark
                          ? const Color(0xFF1A1A2E)
                          : Colors.white,
                      style: GoogleFonts.inter(color: textColor),
                      items: const [
                        DropdownMenuItem(
                          value: 'watch_count',
                          child: Text('Watch Count'),
                        ),
                        DropdownMenuItem(
                          value: 'streak_days',
                          child: Text('Streak Days'),
                        ),
                        DropdownMenuItem(
                          value: 'earn_points',
                          child: Text('Earn Points'),
                        ),
                        DropdownMenuItem(
                          value: 'like_count',
                          child: Text('Like Count'),
                        ),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => conditionType = v!),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      'Condition Value',
                      valueCtrl,
                      isDark,
                      textColor,
                      isNumber: true,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      'Reward Points',
                      rewardCtrl,
                      isDark,
                      textColor,
                      isNumber: true,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Duration',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButton<int>(
                      value: durationDays,
                      isExpanded: true,
                      dropdownColor: isDark
                          ? const Color(0xFF1A1A2E)
                          : Colors.white,
                      style: GoogleFonts.inter(color: textColor),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 Day')),
                        DropdownMenuItem(value: 3, child: Text('3 Days')),
                        DropdownMenuItem(value: 7, child: Text('1 Week')),
                        DropdownMenuItem(value: 14, child: Text('2 Weeks')),
                        DropdownMenuItem(value: 30, child: Text('1 Month')),
                      ],
                      onChanged: (v) => setDialogState(() => durationDays = v!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(color: textColor),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Create',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && titleCtrl.text.trim().isNotEmpty) {
      final now = DateTime.now();
      final campaign = CampaignModel(
        campaignId: const Uuid().v4(),
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
        startTime: now,
        endTime: now.add(Duration(days: durationDays)),
        conditionType: conditionType,
        conditionValue: int.tryParse(valueCtrl.text) ?? 20,
        rewardPoints: int.tryParse(rewardCtrl.text) ?? 50,
      );
      await _campaignService.createCampaign(campaign);
      setState(() => _loading = true);
      await _loadData();
    }

    titleCtrl.dispose();
    descCtrl.dispose();
    valueCtrl.dispose();
    rewardCtrl.dispose();
  }

  Future<void> _toggleCampaign(CampaignModel campaign) async {
    await _campaignService.updateCampaign(campaign.campaignId, {
      'isActive': !campaign.isActive,
    });
    setState(() => _loading = true);
    await _loadData();
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl,
    bool isDark,
    Color textColor, {
    int maxLines = 1,
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: GoogleFonts.inter(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark
                ? Colors.white.withAlpha(8)
                : Colors.grey.withAlpha(20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
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
          'Manage Campaigns',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: accent, strokeWidth: 2),
            )
          : _campaigns.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.campaign_outlined, size: 48, color: subColor),
                  const SizedBox(height: 12),
                  Text(
                    'No campaigns yet',
                    style: GoogleFonts.inter(color: subColor),
                  ),
                  Text(
                    'Tap + to create one',
                    style: GoogleFonts.inter(color: subColor, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _campaigns.length,
              itemBuilder: (ctx, i) {
                final campaign = _campaigns[i];
                final isLive = campaign.isLive;
                return FadeInSlide(
                  delay: i * 50,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isLive
                            ? Colors.green.withAlpha(60)
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
                            Expanded(
                              child: Text(
                                campaign.title,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: textColor,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isLive
                                    ? Colors.green.withAlpha(20)
                                    : Colors.red.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isLive
                                    ? 'LIVE'
                                    : (campaign.isActive
                                          ? 'SCHEDULED'
                                          : 'INACTIVE'),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isLive ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (campaign.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            campaign.description,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: subColor,
                            ),
                            maxLines: 2,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildTag(
                              Icons.flag_rounded,
                              campaign.conditionType.replaceAll('_', ' '),
                              subColor,
                            ),
                            const SizedBox(width: 8),
                            _buildTag(
                              Icons.track_changes_rounded,
                              'Target: ${campaign.conditionValue}',
                              subColor,
                            ),
                            const SizedBox(width: 8),
                            _buildTag(
                              Icons.stars_rounded,
                              '${campaign.rewardPoints} pts',
                              const Color(0xFFFFD700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_formatDate(campaign.startTime)} - ${_formatDate(campaign.endTime)}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: subColor,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _toggleCampaign(campaign),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: campaign.isActive
                                        ? Colors.red.withAlpha(60)
                                        : Colors.green.withAlpha(60),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  campaign.isActive ? 'Deactivate' : 'Activate',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: campaign.isActive
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildTag(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

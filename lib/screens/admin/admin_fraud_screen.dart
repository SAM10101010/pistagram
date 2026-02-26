import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/fraud_service.dart';

class AdminFraudScreen extends StatefulWidget {
  const AdminFraudScreen({super.key});

  @override
  State<AdminFraudScreen> createState() => _AdminFraudScreenState();
}

class _AdminFraudScreenState extends State<AdminFraudScreen> {
  final _fraud = FraudService();
  List<Map<String, dynamic>> _flags = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final flags = await _fraud.getUnresolvedFlags();
      if (mounted) {
        setState(() {
          _flags = flags;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading fraud flags: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _action(Map<String, dynamic> flag, String action) async {
    final uid = flag['uid'] as String? ?? '';
    if (uid.isEmpty) return;

    try {
      switch (action) {
        case 'dismiss':
          // Just remove from list
          break;
        case 'disableRewards':
          await _fraud.disableRewards(uid);
          break;
        case 'freezeWallet':
          await _fraud.freezeWallet(uid);
          break;
        case 'suspend':
          await _fraud.suspendAccount(uid);
          break;
      }

      if (mounted) {
        setState(() => _flags.remove(flag));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action "$action" applied'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Action failed'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
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
        title: Text('Fraud Detection', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: textColor), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : _flags.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user, size: 64, color: Colors.green),
                      const SizedBox(height: 12),
                      Text('No fraud flags', style: GoogleFonts.inter(color: subColor, fontSize: 15)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _flags.length,
                  itemBuilder: (ctx, i) {
                    final flag = _flags[i];
                    final uid = flag['uid'] as String? ?? 'Unknown';
                    final reason = flag['reason'] as String? ?? 'Unknown reason';
                    final timestamp = flag['timestamp'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.flag, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('User: ${uid.length > 14 ? '${uid.substring(0, 14)}...' : uid}',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Reason: $reason', style: GoogleFonts.inter(fontSize: 13, color: subColor)),
                          if (timestamp != null)
                            Text('Time: ${timestamp.toString().substring(0, 19)}', style: GoogleFonts.inter(fontSize: 11, color: subColor)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _actionChip('Dismiss', Icons.close, subColor, () => _action(flag, 'dismiss')),
                              _actionChip('Disable Rewards', Icons.block, Colors.orange, () => _action(flag, 'disableRewards')),
                              _actionChip('Freeze Wallet', Icons.ac_unit, Colors.blue, () => _action(flag, 'freezeWallet')),
                              _actionChip('Suspend', Icons.person_off, Colors.redAccent, () => _action(flag, 'suspend')),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _actionChip(String label, IconData icon, Color color, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: GoogleFonts.inter(fontSize: 11, color: color)),
      backgroundColor: color.withAlpha(20),
      side: BorderSide.none,
      onPressed: onTap,
    );
  }
}

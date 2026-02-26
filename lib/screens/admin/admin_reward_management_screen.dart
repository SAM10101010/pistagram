import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/reward_model.dart';

class AdminRewardManagementScreen extends StatefulWidget {
  const AdminRewardManagementScreen({super.key});

  @override
  State<AdminRewardManagementScreen> createState() => _AdminRewardManagementScreenState();
}

class _AdminRewardManagementScreenState extends State<AdminRewardManagementScreen> {
  final _firestore = FirebaseFirestore.instance;
  List<RewardModel> _rewards = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await _firestore.collection('rewards').get();
      final rewards = snap.docs.map((d) => RewardModel.fromMap(d.data())).toList();
      if (mounted) {
        setState(() {
          _rewards = rewards;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading rewards: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(RewardModel reward) async {
    await _firestore.collection('rewards').doc(reward.id).update({'isActive': !reward.isActive});
    _load();
  }

  Future<void> _delete(RewardModel reward) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reward'),
        content: Text('Delete "${reward.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed == true) {
      await _firestore.collection('rewards').doc(reward.id).delete();
      _load();
    }
  }

  void _showAddEditDialog({RewardModel? existing}) {
    final titleC = TextEditingController(text: existing?.title ?? '');
    final descC = TextEditingController(text: existing?.description ?? '');
    final imageC = TextEditingController(text: existing?.imageUrl ?? '');
    final costC = TextEditingController(text: existing?.pointsCost.toString() ?? '');
    final stockC = TextEditingController(text: existing?.stock.toString() ?? '0');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Reward' : 'Edit Reward', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Title'), style: TextStyle(color: textColor)),
              const SizedBox(height: 8),
              TextField(controller: descC, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2, style: TextStyle(color: textColor)),
              const SizedBox(height: 8),
              TextField(controller: imageC, decoration: const InputDecoration(labelText: 'Image URL'), style: TextStyle(color: textColor)),
              const SizedBox(height: 8),
              TextField(controller: costC, decoration: const InputDecoration(labelText: 'Points Cost'), keyboardType: TextInputType.number, style: TextStyle(color: textColor)),
              const SizedBox(height: 8),
              TextField(controller: stockC, decoration: const InputDecoration(labelText: 'Stock (0 = unlimited)'), keyboardType: TextInputType.number, style: TextStyle(color: textColor)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final title = titleC.text.trim();
              final cost = int.tryParse(costC.text.trim()) ?? 0;
              if (title.isEmpty || cost <= 0) return;

              final data = {
                'title': title,
                'description': descC.text.trim(),
                'imageUrl': imageC.text.trim(),
                'pointsCost': cost,
                'stock': int.tryParse(stockC.text.trim()) ?? 0,
                'isActive': true,
                'createdAt': FieldValue.serverTimestamp(),
              };

              if (existing != null) {
                data.remove('createdAt');
                await _firestore.collection('rewards').doc(existing.id).update(data);
              } else {
                final doc = _firestore.collection('rewards').doc();
                data['id'] = doc.id;
                await doc.set(data);
              }

              Navigator.pop(ctx);
              _load();
            },
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
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
        title: Text('Reward Management', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: textColor), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: accent),
            onPressed: () => _showAddEditDialog(),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : _rewards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.card_giftcard, size: 64, color: subColor),
                      const SizedBox(height: 12),
                      Text('No rewards yet', style: GoogleFonts.inter(color: subColor, fontSize: 15)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showAddEditDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Reward'),
                        style: ElevatedButton.styleFrom(backgroundColor: accent),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _rewards.length,
                  itemBuilder: (ctx, i) {
                    final reward = _rewards[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: accent.withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.card_giftcard, color: accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(reward.title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                                const SizedBox(height: 2),
                                Text('${reward.pointsCost} pts • Stock: ${reward.stock > 0 ? reward.stock : '∞'}',
                                    style: GoogleFonts.inter(fontSize: 12, color: subColor)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(reward.isActive ? Icons.toggle_on : Icons.toggle_off, color: reward.isActive ? Colors.green : subColor, size: 32),
                            onPressed: () => _toggleActive(reward),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: subColor),
                            onSelected: (val) {
                              if (val == 'edit') _showAddEditDialog(existing: reward);
                              if (val == 'delete') _delete(reward);
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
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

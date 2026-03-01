import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/creator_growth_service.dart';

class CreatorGrowthScreen extends StatefulWidget {
  const CreatorGrowthScreen({super.key});

  @override
  State<CreatorGrowthScreen> createState() => _CreatorGrowthScreenState();
}

class _CreatorGrowthScreenState extends State<CreatorGrowthScreen> {
  final _service = CreatorGrowthService();
  Map<String, dynamic> _metrics = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final data = await _service.getGrowthMetrics(uid);
    if (mounted) setState(() { _metrics = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Creator Growth')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statCard('Growth Rate', '${(_metrics['growthRate'] ?? 0.0).toStringAsFixed(2)} followers/day', Icons.trending_up, Colors.green),
                  _statCard('Retention Trend', '${(_metrics['retentionTrend'] ?? 0.0).toStringAsFixed(1)}%', Icons.replay, Colors.blue),
                  _statCard('Engagement Depth', '${(_metrics['engagementDepth'] ?? 0.0).toStringAsFixed(1)}%', Icons.thumb_up, Colors.purple),
                  _statCard('Total Views', '${_metrics['totalViews'] ?? 0}', Icons.visibility, Colors.teal),
                  const SizedBox(height: 16),
                  const Text('Badges', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ((_metrics['badges'] ?? []) as List).map((b) => Chip(
                      avatar: const Icon(Icons.star, size: 16, color: Colors.amber),
                      label: Text(b.toString(), style: const TextStyle(fontSize: 12)),
                    )).toList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color, size: 20)),
        title: Text(title, style: const TextStyle(fontSize: 13)),
        trailing: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/transparency_service.dart';

class TransparencyScreen extends StatefulWidget {
  final String reelId;
  const TransparencyScreen({super.key, required this.reelId});

  @override
  State<TransparencyScreen> createState() => _TransparencyScreenState();
}

class _TransparencyScreenState extends State<TransparencyScreen> {
  final _service = TransparencyService();
  Map<String, dynamic> _data = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _service.getReelRankingBreakdown(widget.reelId);
    if (mounted) setState(() { _data = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Why This Ranked')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ranking Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _row('Quality Score', '${(_data['qualityScore'] ?? 0.0).toStringAsFixed(1)}'),
                  _row('Retention', '${(_data['retentionPercent'] ?? 0.0).toStringAsFixed(1)}%'),
                  _row('Discussion Depth', '${(_data['discussionDepth'] ?? 0.0).toStringAsFixed(2)}'),
                  _row('Save Rate', '${(_data['saveRate'] ?? 0.0).toStringAsFixed(1)}%'),
                  _row('Momentum', '${(_data['momentumScore'] ?? 0.0).toStringAsFixed(1)}'),
                  _row('Lifecycle', '${_data['lifecycleStage'] ?? 'fresh'}'),
                  _row('Content Type', '${_data['contentType'] ?? 'other'}'),
                  _row('Quality Verified', '${_data['qualityVerified'] ?? false}'),
                  _row('Ranking Weight', '${(_data['rankingWeight'] ?? 1.0).toStringAsFixed(2)}'),
                  _row('Visibility', '${(_data['visibilityMultiplier'] ?? 1.0).toStringAsFixed(2)}'),
                ],
              ),
            ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/quality_audit_service.dart';

class QualityScoreScreen extends StatefulWidget {
  final String reelId;
  const QualityScoreScreen({super.key, required this.reelId});

  @override
  State<QualityScoreScreen> createState() => _QualityScoreScreenState();
}

class _QualityScoreScreenState extends State<QualityScoreScreen> {
  final _service = QualityAuditService();
  Map<String, dynamic> _breakdown = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _service.calculateQualityScore(widget.reelId);
    if (mounted) setState(() { _breakdown = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Quality Score')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _scoreCircle(theme),
                  const SizedBox(height: 24),
                  if (_breakdown['qualityVerified'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, color: Colors.green, size: 18),
                          SizedBox(width: 6),
                          Text('Quality Verified', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  _metricRow('Retention %', '${(_breakdown['retentionPercent'] ?? 0.0).toStringAsFixed(1)}%', Colors.blue),
                  _metricRow('Discussion Depth', '${(_breakdown['discussionDepth'] ?? 0.0).toStringAsFixed(2)}', Colors.purple),
                  _metricRow('Save Rate', '${(_breakdown['saveRate'] ?? 0.0).toStringAsFixed(1)}%', Colors.teal),
                ],
              ),
            ),
    );
  }

  Widget _scoreCircle(ThemeData theme) {
    final score = (_breakdown['qualityScore'] ?? 0.0).toDouble();
    return Column(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(_scoreColor(score)),
                ),
              ),
              Text(score.toStringAsFixed(0), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _scoreColor(score))),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Quality Score', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
      ],
    );
  }

  Color _scoreColor(double score) {
    if (score >= 70) return Colors.green;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  Widget _metricRow(String label, String value, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(Icons.analytics, color: color, size: 20)),
        title: Text(label, style: const TextStyle(fontSize: 13)),
        trailing: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}

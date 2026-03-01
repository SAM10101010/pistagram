import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/trust_score_service.dart';

class TrustLevelScreen extends StatefulWidget {
  const TrustLevelScreen({super.key});

  @override
  State<TrustLevelScreen> createState() => _TrustLevelScreenState();
}

class _TrustLevelScreenState extends State<TrustLevelScreen> {
  final _service = TrustScoreService();
  Map<String, dynamic> _breakdown = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final data = await _service.getTrustBreakdown(uid);
    if (mounted) setState(() { _breakdown = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trust Level')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _trustBadge(),
                  const SizedBox(height: 24),
                  _factorCard('Account Age Bonus', '+${(_breakdown['ageBonus'] ?? 0.0).toStringAsFixed(1)}', Colors.blue),
                  _factorCard('Report Accuracy', '+${(_breakdown['reportAccuracy'] ?? 0.0).toStringAsFixed(1)}', Colors.green),
                  _factorCard('Report Penalty', '-${(_breakdown['reportPenalty'] ?? 0.0).toStringAsFixed(1)}', Colors.orange),
                  _factorCard('Spam Penalty', '-${(_breakdown['spamPenalty'] ?? 0.0).toStringAsFixed(1)}', Colors.red),
                ],
              ),
            ),
    );
  }

  Widget _trustBadge() {
    final level = _breakdown['trustLevel'] ?? 'normal';
    final score = (_breakdown['trustScore'] ?? 50.0).toDouble();
    final color = _levelColor(level);
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(Icons.shield, color: color, size: 40),
        ),
        const SizedBox(height: 12),
        Text(level.toUpperCase(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text('Score: ${score.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'elite': return Colors.purple;
      case 'high': return Colors.green;
      case 'normal': return Colors.blue;
      default: return Colors.red;
    }
  }

  Widget _factorCard(String label, String value, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label, style: const TextStyle(fontSize: 14)),
        trailing: Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}

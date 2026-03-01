import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/account_health_service.dart';
import 'trust_level_screen.dart';

class AccountHealthScreen extends StatefulWidget {
  const AccountHealthScreen({super.key});

  @override
  State<AccountHealthScreen> createState() => _AccountHealthScreenState();
}

class _AccountHealthScreenState extends State<AccountHealthScreen> {
  final _service = AccountHealthService();
  Map<String, dynamic> _breakdown = {};
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final data = await _service.getHealthBreakdown(uid);
      final history = await _service.getHealthHistory(uid);
      if (mounted) {
        setState(() {
          _breakdown = data;
          _history = history;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading account health: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Health')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'Could not load account health',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please try again later',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _healthGauge(),
                    const SizedBox(height: 16),
                    _warningBanner(),
                    const SizedBox(height: 16),
                    _componentCard('Trust Score', 'trustComponent', 0.40, Colors.blue),
                    _componentCard('Report History', 'reportComponent', 0.20, Colors.green),
                    _componentCard('Comment Behavior', 'commentComponent', 0.15, Colors.teal),
                    _componentCard('Spam Activity', 'spamComponent', 0.15, Colors.orange),
                    _componentCard('Violation History', 'violationComponent', 0.10, Colors.red),
                    const SizedBox(height: 12),
                    _trustLink(),
                    const SizedBox(height: 20),
                    if (_history.isNotEmpty) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Health History',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._history.map(_historyTile),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _healthGauge() {
    final score = (_breakdown['healthScore'] ?? 75.0).toDouble();
    final level = _breakdown['healthLevel'] ?? 'green';
    final color = _levelColor(level);

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
                  strokeWidth: 10,
                  backgroundColor: color.withValues(alpha:0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    score.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    level.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _levelDescription(level),
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _warningBanner() {
    final score = (_breakdown['healthScore'] ?? 75.0).toDouble();
    if (score >= 70) return const SizedBox.shrink();

    final limits = _service.getFeatureLimits(score);
    final color = score >= 40 ? Colors.orange : Colors.red;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                score >= 40 ? 'Account Warning' : 'Account Restricted',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Your account health is low. Some features may be limited.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          if (limits['commentLimit'] != -1)
            Text(
              'Comment limit: ${limits['commentLimit']} per hour',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          if ((limits['reachReduction'] as double) > 0)
            Text(
              'Reach reduced by ${((limits['reachReduction'] as double) * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }

  Widget _componentCard(String label, String key, double weight, Color color) {
    final value = (_breakdown[key] ?? 0.0).toDouble();
    final maxValue = 100.0 * weight;
    final percentage = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                Text(
                  '${value.toStringAsFixed(1)} / ${maxValue.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: color.withValues(alpha:0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${(weight * 100).toStringAsFixed(0)}% weight',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trustLink() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.shield, color: Colors.blue),
        title: const Text('View Trust Score Details'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TrustLevelScreen()),
          );
        },
      ),
    );
  }

  Widget _historyTile(Map<String, dynamic> entry) {
    final oldScore = (entry['oldScore'] ?? 0.0).toDouble();
    final newScore = (entry['newScore'] ?? 0.0).toDouble();
    final component = entry['component'] ?? '';
    final reason = entry['reason'] ?? '';
    final timestamp = entry['timestamp'];
    final date = timestamp is DateTime
        ? timestamp
        : (timestamp as dynamic)?.toDate() ?? DateTime.now();
    final diff = newScore - oldScore;
    final isPositive = diff >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Icon(
          isPositive ? Icons.arrow_upward : Icons.arrow_downward,
          color: isPositive ? Colors.green : Colors.red,
        ),
        title: Text(
          '${oldScore.toStringAsFixed(1)} → ${newScore.toStringAsFixed(1)}',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: Text(
          '${component.isNotEmpty ? '[$component] ' : ''}$reason',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Text(
          _formatDate(date),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ),
    );
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.orange;
      case 'red':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _levelDescription(String level) {
    switch (level) {
      case 'green':
        return 'Your account is healthy';
      case 'yellow':
        return 'Your account needs attention';
      case 'red':
        return 'Your account is restricted';
      default:
        return '';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

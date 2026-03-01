import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/behavior_profile_service.dart';

class BehaviorProfileScreen extends StatefulWidget {
  const BehaviorProfileScreen({super.key});

  @override
  State<BehaviorProfileScreen> createState() => _BehaviorProfileScreenState();
}

class _BehaviorProfileScreenState extends State<BehaviorProfileScreen> {
  final _service = BehaviorProfileService();
  Map<String, dynamic> _profile = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final data = await _service.updateBehaviorProfile(uid);
    if (mounted) setState(() { _profile = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final type = _profile['behaviorType'] ?? 'Silent Viewer';
    return Scaffold(
      appBar: AppBar(title: const Text('Your Behavior Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: _typeColor(type).withValues(alpha: 0.1),
                    child: Icon(_typeIcon(type), color: _typeColor(type), size: 40),
                  ),
                  const SizedBox(height: 12),
                  Text(type, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _typeColor(type))),
                  const SizedBox(height: 24),
                  _infoTile('Total Watched', '${_profile['totalWatched'] ?? 0}'),
                  _infoTile('Comment Rate', '${(_profile['commentRate'] ?? 0.0).toStringAsFixed(1)}%'),
                  _infoTile('Total Comments', '${_profile['totalComments'] ?? 0}'),
                ],
              ),
            ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'Deep Watcher': return Colors.blue;
      case 'Fast Scroller': return Colors.orange;
      case 'Discussion Leader': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Deep Watcher': return Icons.visibility;
      case 'Fast Scroller': return Icons.speed;
      case 'Discussion Leader': return Icons.chat;
      default: return Icons.person;
    }
  }

  Widget _infoTile(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label, style: const TextStyle(fontSize: 14)),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}

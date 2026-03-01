import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/challenge_service.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  final _service = ChallengeService();
  List<Map<String, dynamic>> _challenges = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _service.getActiveChallenges();
    if (mounted) setState(() { _challenges = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community Challenges')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _challenges.isEmpty
              ? const Center(child: Text('No active challenges'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _challenges.length,
                    itemBuilder: (context, index) {
                      final c = _challenges[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.emoji_events, color: Colors.amber, size: 24),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(c['title'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                                ],
                              ),
                              if ((c['description'] ?? '').isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(c['description'], style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Chip(label: Text('${c['participantCount'] ?? 0} joined', style: const TextStyle(fontSize: 11))),
                                  const SizedBox(width: 8),
                                  Chip(label: Text('${c['rewardPoints'] ?? 0} pts', style: const TextStyle(fontSize: 11))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: () async {
                                    final uid = FirebaseAuth.instance.currentUser?.uid;
                                    if (uid == null) return;
                                    final joined = await _service.hasJoined(c['id'] ?? '', uid);
                                    if (!joined) {
                                      await _service.joinChallenge(c['id'] ?? '', uid);
                                      if (mounted) _load();
                                    }
                                  },
                                  child: const Text('Join Challenge'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

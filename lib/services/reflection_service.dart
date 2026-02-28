import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reflection_model.dart';

class ReflectionService {
  final _firestore = FirebaseFirestore.instance;

  static const _prompts = [
    'What did you learn from what you just watched?',
    'What inspired you the most?',
    'How did the content make you feel?',
    'Would you share any of these reels with a friend? Why?',
    'What new perspective did you gain?',
    'Did anything surprise you?',
    'What would you like to see more of?',
    'How does this relate to your own life?',
    'What was the most creative thing you saw?',
    'Did you discover a new creator you liked?',
  ];

  int _sessionReelCount = 0;
  final List<String> _sessionReelIds = [];

  void onReelWatched(String reelId) {
    _sessionReelCount++;
    _sessionReelIds.add(reelId);
  }

  bool shouldShowPrompt() => _sessionReelCount > 0 && _sessionReelCount % 5 == 0;

  void resetSession() {
    _sessionReelCount = 0;
    _sessionReelIds.clear();
  }

  List<String> getSessionReelIds() => List.from(_sessionReelIds);

  String getRandomPrompt() {
    final random = Random();
    return _prompts[random.nextInt(_prompts.length)];
  }

  List<String> getRandomPrompts({int count = 3}) {
    final shuffled = List<String>.from(_prompts)..shuffle();
    return shuffled.take(count).toList();
  }

  Future<void> saveReflection(String userId, String prompt, String response, List<String> reelIds) async {
    final ref = _firestore.collection('reflections').doc();
    final reflection = ReflectionModel(
      reflectionId: ref.id,
      userId: userId,
      prompt: prompt,
      response: response,
      reelIdsWatched: reelIds,
    );
    await ref.set(reflection.toMap());
  }

  Future<List<ReflectionModel>> getUserReflections(String userId, {int limit = 20}) async {
    final snapshot = await _firestore
        .collection('reflections')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((d) => ReflectionModel.fromMap(d.data())).toList();
  }
}

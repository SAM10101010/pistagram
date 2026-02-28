import 'package:cloud_firestore/cloud_firestore.dart';

class LifecycleService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> updateReelLifecycle(String reelId) async {
    final ref = _firestore.collection('reels').doc(reelId);
    final doc = await ref.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final viewsCount = data['viewsCount'] as int? ?? 0;
    final prevVelocity = (data['viewVelocity'] as num? ?? 0.0).toDouble();

    final now = DateTime.now();
    final ageHours = now.difference(createdAt).inHours.clamp(1, 999999);
    final viewVelocity = viewsCount / ageHours;

    double engagementGrowthRate = 0.0;
    if (prevVelocity > 0) {
      engagementGrowthRate = ((viewVelocity - prevVelocity) / prevVelocity) * 100;
    }

    final stage = calculateStage(viewVelocity, engagementGrowthRate, ageHours);

    await ref.update({
      'lifecycleStage': stage,
      'viewVelocity': viewVelocity,
      'engagementGrowthRate': engagementGrowthRate,
      'lastVelocityCalculation': Timestamp.now(),
    });
  }

  String calculateStage(double viewVelocity, double engagementGrowthRate, int ageHours) {
    if (ageHours < 24) return 'fresh';
    if (viewVelocity > 5 && engagementGrowthRate > 10) return 'trending';
    if (engagementGrowthRate < -20) return 'fading';
    return 'stable';
  }

  String getStageColor(String stage) {
    switch (stage) {
      case 'fresh':
        return '#4CAF50';
      case 'trending':
        return '#FF9800';
      case 'stable':
        return '#2196F3';
      case 'fading':
        return '#9E9E9E';
      default:
        return '#9E9E9E';
    }
  }

  String getStageLabel(String stage) {
    switch (stage) {
      case 'fresh':
        return 'Fresh';
      case 'trending':
        return 'Trending';
      case 'stable':
        return 'Stable';
      case 'fading':
        return 'Fading';
      default:
        return 'Unknown';
    }
  }
}

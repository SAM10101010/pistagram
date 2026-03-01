import 'package:cloud_firestore/cloud_firestore.dart';

class LifecycleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String calculateLifecycleStage(double velocity, double growthRate, int ageHours) {
    if (ageHours < 24) return 'new';
    if (growthRate > 0.1 && velocity > 5) return 'trending';
    if (growthRate > -0.05) return 'stable';
    return 'declining';
  }

  Future<void> updateLifecycle(String reelId) async {
    final doc = await _db.collection('reels').doc(reelId).get();
    if (!doc.exists) return;
    final data = doc.data()!;

    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final ageHours = DateTime.now().difference(createdAt).inHours;
    final views = (data['viewsCount'] ?? 0) as int;
    final previousVelocity = (data['viewVelocity'] ?? 0.0).toDouble();

    double velocity = ageHours > 0 ? views / ageHours : 0;
    double growthRate = previousVelocity > 0
        ? (velocity - previousVelocity) / previousVelocity
        : 0;

    String stage = calculateLifecycleStage(velocity, growthRate, ageHours);

    await _db.collection('reels').doc(reelId).update({
      'lifecycleStage': stage,
      'viewVelocity': velocity,
      'engagementGrowthRate': growthRate,
      'lastVelocityCalculation': Timestamp.fromDate(DateTime.now()),
    });
  }

  String getLifecycleLabel(String stage) {
    switch (stage) {
      case 'new': return 'New';
      case 'trending': return 'Trending';
      case 'stable': return 'Stable';
      case 'declining': return 'Declining';
      default: return 'Fresh';
    }
  }
}

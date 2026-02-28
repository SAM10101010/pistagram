import 'package:cloud_firestore/cloud_firestore.dart';

class ConsistencyService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> onReelUploaded(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'reelsUploadedThisMonth': FieldValue.increment(1),
    });
    await recalculateConsistency(userId);
  }

  Future<void> recalculateConsistency(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    final data = userDoc.data()!;
    final reelsThisMonth = data['reelsUploadedThisMonth'] as int? ?? 0;
    final avgGap = (data['avgUploadGapDays'] as num? ?? 0.0).toDouble();

    double score = 0.0;

    // Frequency component (up to 50 points)
    score += (reelsThisMonth * 5).clamp(0, 50).toDouble();

    // Regularity component (up to 50 points) - lower gap = higher score
    if (avgGap > 0 && avgGap <= 2) {
      score += 50;
    } else if (avgGap <= 5) {
      score += 35;
    } else if (avgGap <= 10) {
      score += 20;
    } else if (avgGap <= 20) {
      score += 10;
    }

    score = score.clamp(0, 100);
    final badge = getBadge(score);

    await _firestore.collection('users').doc(userId).update({
      'consistencyScore': score,
      'consistencyBadge': badge,
    });
  }

  String getBadge(double score) {
    if (score > 70) return 'consistent_creator';
    if (score >= 30) return 'irregular_creator';
    return 'new_creator';
  }

  String getBadgeLabel(String badge) {
    switch (badge) {
      case 'consistent_creator':
        return 'Consistent Creator';
      case 'irregular_creator':
        return 'Irregular Creator';
      case 'new_creator':
        return 'New Creator';
      default:
        return 'Creator';
    }
  }

  String getBadgeColor(String badge) {
    switch (badge) {
      case 'consistent_creator':
        return '#4CAF50';
      case 'irregular_creator':
        return '#FF9800';
      case 'new_creator':
        return '#2196F3';
      default:
        return '#9E9E9E';
    }
  }
}

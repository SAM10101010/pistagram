import 'firestore_service.dart';

class AnalyticsService {
  final FirestoreService _firestoreService = FirestoreService();

  Future<Map<String, dynamic>> getCreatorDashboard(String uid) async {
    final reels = await _firestoreService.getReelsByUser(uid);
    final user = await _firestoreService.getUser(uid);

    int totalViews = 0;
    int totalLikes = 0;
    int totalComments = 0;
    double avgCompletion = 0;

    for (final reel in reels) {
      totalViews += reel.viewsCount;
      totalLikes += reel.likesCount;
      totalComments += reel.commentsCount;
      avgCompletion += reel.completionRate;
    }

    if (reels.isNotEmpty) {
      avgCompletion /= reels.length;
    }

    return {
      'totalReels': reels.length,
      'totalViews': totalViews,
      'totalLikes': totalLikes,
      'totalComments': totalComments,
      'avgCompletionRate': avgCompletion,
      'followersCount': user?.followersCount ?? 0,
      'engagementRate': totalViews > 0
          ? ((totalLikes + totalComments) / totalViews * 100)
          : 0.0,
    };
  }

  Future<Map<String, dynamic>> getReelAnalytics(String reelId) async {
    final reel = await _firestoreService.getReel(reelId);
    if (reel == null) return {};

    return {
      'views': reel.viewsCount,
      'likes': reel.likesCount,
      'comments': reel.commentsCount,
      'completionRate': reel.completionRate,
      'engagementRate': reel.viewsCount > 0
          ? ((reel.likesCount + reel.commentsCount) / reel.viewsCount * 100)
          : 0.0,
    };
  }
}

import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../models/reel_model.dart';
import 'firestore_service.dart';
import 'cloudinary_service.dart';

class ReelService {
  final FirestoreService _firestoreService = FirestoreService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final _uuid = const Uuid();

  Future<ReelModel> uploadReel({
    required String creatorUid,
    required XFile videoFile,
    String caption = '',
    List<String> hashtags = const [],
    String visibility = 'public',
  }) async {
    // Upload to Cloudinary
    final file = File(videoFile.path);
    final result = await _cloudinaryService.uploadVideo(file);

    final reelId = _uuid.v4();
    final reel = ReelModel(
      reelId: reelId,
      creatorUid: creatorUid,
      videoUrl: result['url'] ?? '',
      cloudinaryPublicId: result['publicId'] ?? '',
      caption: caption,
      hashtags: hashtags.map((h) => h.toLowerCase().replaceAll('#', '')).toList(),
      visibility: visibility,
    );

    await _firestoreService.createReel(reel);
    return reel;
  }

  Future<void> deleteReel(String reelId) async {
    final reel = await _firestoreService.getReel(reelId);
    if (reel != null && reel.cloudinaryPublicId.isNotEmpty) {
      await _cloudinaryService.deleteFile(reel.cloudinaryPublicId);
    }
    await _firestoreService.deleteReel(reelId);
  }

  Future<void> updateVisibility(String reelId, String visibility) async {
    await _firestoreService.updateReel(reelId, {'visibility': visibility});
  }

  Future<List<ReelModel>> getReelsByUser(String uid) async {
    return await _firestoreService.getReelsByUser(uid);
  }

  Future<List<ReelModel>> getPublicReels({int limit = 20}) async {
    return await _firestoreService.getPublicReels(limit: limit);
  }

  Future<List<ReelModel>> getFeedReels(String uid, {int limit = 20}) async {
    final followingUids = await _firestoreService.getFollowingUids(uid);
    if (followingUids.isEmpty) {
      // If not following anyone, show public reels
      return await _firestoreService.getPublicReels(limit: limit);
    }
    return await _firestoreService.getFeedReels(followingUids, limit: limit);
  }

  Future<List<ReelModel>> getTrendingReels({int limit = 20}) async {
    return await _firestoreService.getTrendingReels(limit: limit);
  }

  Future<List<ReelModel>> getReelsByHashtag(String hashtag, {int limit = 20}) async {
    return await _firestoreService.getReelsByHashtag(hashtag, limit: limit);
  }

  Future<void> incrementViews(String reelId) async {
    await _firestoreService.incrementViews(reelId);
  }
}

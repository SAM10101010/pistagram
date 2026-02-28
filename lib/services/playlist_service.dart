import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/playlist_model.dart';

class PlaylistService {
  final _firestore = FirebaseFirestore.instance;

  Future<PlaylistModel> createPlaylist(String ownerId, String title, String description) async {
    final ref = _firestore.collection('playlists').doc();
    final playlist = PlaylistModel(
      playlistId: ref.id,
      ownerId: ownerId,
      title: title,
      description: description,
    );
    await ref.set(playlist.toMap());
    return playlist;
  }

  Future<void> addReelToPlaylist(String playlistId, String reelId, String adderId) async {
    final ref = _firestore.collection('playlists').doc(playlistId);
    final doc = await ref.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final ownerId = data['ownerId'] as String;
    final collaborators = List<String>.from(data['collaboratorIds'] ?? []);
    final isCollaborative = data['isCollaborative'] as bool? ?? false;

    if (adderId != ownerId && !(isCollaborative && collaborators.contains(adderId))) return;

    await ref.update({
      'reelIds': FieldValue.arrayUnion([reelId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeReelFromPlaylist(String playlistId, String reelId, String removerId) async {
    final ref = _firestore.collection('playlists').doc(playlistId);
    final doc = await ref.get();
    if (!doc.exists) return;

    final ownerId = doc.data()!['ownerId'] as String;
    if (removerId != ownerId) return;

    await ref.update({
      'reelIds': FieldValue.arrayRemove([reelId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> followPlaylist(String playlistId, String followerId) async {
    final docId = '${playlistId}_$followerId';
    await _firestore.collection('playlistFollows').doc(docId).set({
      'playlistId': playlistId,
      'followerId': followerId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _firestore.collection('playlists').doc(playlistId).update({
      'followerCount': FieldValue.increment(1),
    });
  }

  Future<void> unfollowPlaylist(String playlistId, String followerId) async {
    final docId = '${playlistId}_$followerId';
    await _firestore.collection('playlistFollows').doc(docId).delete();
    await _firestore.collection('playlists').doc(playlistId).update({
      'followerCount': FieldValue.increment(-1),
    });
  }

  Future<List<PlaylistModel>> getUserPlaylists(String userId) async {
    final snapshot = await _firestore
        .collection('playlists')
        .where('ownerId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .get();

    return snapshot.docs.map((d) => PlaylistModel.fromMap(d.data())).toList();
  }

  Future<List<PlaylistModel>> getFollowedPlaylists(String userId) async {
    final followsSnapshot = await _firestore
        .collection('playlistFollows')
        .where('followerId', isEqualTo: userId)
        .get();

    final playlistIds = followsSnapshot.docs.map((d) => d.data()['playlistId'] as String).toList();
    if (playlistIds.isEmpty) return [];

    final List<PlaylistModel> playlists = [];
    for (final id in playlistIds) {
      final doc = await _firestore.collection('playlists').doc(id).get();
      if (doc.exists) playlists.add(PlaylistModel.fromMap(doc.data()!));
    }
    return playlists;
  }

  Future<void> addCollaborator(String playlistId, String ownerId, String collaboratorId) async {
    final ref = _firestore.collection('playlists').doc(playlistId);
    final doc = await ref.get();
    if (!doc.exists || doc.data()!['ownerId'] != ownerId) return;

    await ref.update({
      'collaboratorIds': FieldValue.arrayUnion([collaboratorId]),
      'isCollaborative': true,
    });
  }

  Future<void> removeCollaborator(String playlistId, String ownerId, String collaboratorId) async {
    final ref = _firestore.collection('playlists').doc(playlistId);
    final doc = await ref.get();
    if (!doc.exists || doc.data()!['ownerId'] != ownerId) return;

    await ref.update({
      'collaboratorIds': FieldValue.arrayRemove([collaboratorId]),
    });
  }

  Future<bool> isFollowing(String playlistId, String userId) async {
    final docId = '${playlistId}_$userId';
    final doc = await _firestore.collection('playlistFollows').doc(docId).get();
    return doc.exists;
  }
}

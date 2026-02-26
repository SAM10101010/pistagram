import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';
import 'cloudinary_service.dart';

class ProfileService {
  final FirestoreService _firestoreService = FirestoreService();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  Future<UserModel?> getProfile(String uid) async {
    return await _firestoreService.getUser(uid);
  }

  Stream<UserModel?> profileStream(String uid) {
    return _firestoreService.userStream(uid);
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    await _firestoreService.updateUser(uid, data);
  }

  Future<String> uploadProfilePic(String uid, XFile imageFile) async {
    final file = File(imageFile.path);
    final result = await _cloudinaryService.uploadProfilePic(file);
    final url = result['url'] ?? '';
    await _firestoreService.updateUser(uid, {'profilePicUrl': url});
    return url;
  }

  Future<void> toggleAccountType(String uid, String type) async {
    await _firestoreService.updateUser(uid, {'accountType': type});
  }

  Future<void> updatePrivacySettings(
      String uid, Map<String, dynamic> settings) async {
    await _firestoreService.updateUser(uid, {'privacySettings': settings});
  }

  Future<void> softDeleteAccount(String uid) async {
    await _firestoreService.updateUser(uid, {
      'accountStatus': 'deleted',
      'email': '',
      'username': 'deleted_user',
      'bio': '',
      'profilePicUrl': '',
    });
  }
}

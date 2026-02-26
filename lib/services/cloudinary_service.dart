import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class CloudinaryService {
  // ── Cloudinary Config ──
  static const String cloudName = 'dahc7jlax';
  static const String uploadPreset = 'pistagram_unsigned';
  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$cloudName/auto/upload';

  static const int _maxRetries = 3;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 120),
    sendTimeout: const Duration(seconds: 120),
  ));

  /// Upload a file to Cloudinary using UNSIGNED preset with retry logic
  Future<Map<String, String>> uploadFile(File file, {String folder = 'reels'}) async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(file.path),
          'upload_preset': uploadPreset,
          'folder': folder,
        });

        debugPrint('⬆️ Cloudinary: uploading ${file.path} to $folder (attempt $attempt)...');
        final response = await _dio.post(_uploadUrl, data: formData);
        if (response.statusCode == 200) {
          final data = response.data;
          debugPrint('✅ Cloudinary: upload success — ${data['secure_url']}');
          return {
            'url': data['secure_url'] ?? data['url'] ?? '',
            'publicId': data['public_id'] ?? '',
          };
        }
        throw Exception('Upload failed with status: ${response.statusCode}');
      } on DioException catch (e) {
        final statusCode = e.response?.statusCode ?? 0;
        final body = e.response?.data?.toString() ?? 'No response body';
        debugPrint('❌ Cloudinary DioError ($statusCode): $body (attempt $attempt)');

        if (statusCode == 400 && body.contains('preset')) {
          throw Exception(
            'Upload preset "$uploadPreset" not found. '
            'Go to Cloudinary Dashboard → Settings → Upload → Upload Presets → '
            'Add preset named "$uploadPreset" with Signing Mode = Unsigned'
          );
        }
        if (statusCode == 401) {
          throw Exception('Cloudinary auth failed. Check your cloud name and upload preset.');
        }

        // Retry on network errors (status 0) or server errors (5xx)
        if (attempt < _maxRetries && (statusCode == 0 || statusCode >= 500)) {
          final delay = Duration(seconds: attempt * 2);
          debugPrint('⏳ Retrying in ${delay.inSeconds}s...');
          await Future.delayed(delay);
          continue;
        }
        throw Exception('Upload failed ($statusCode): $body');
      } catch (e) {
        debugPrint('❌ Cloudinary error: $e (attempt $attempt)');
        if (attempt < _maxRetries && e.toString().contains('Upload failed')) {
          rethrow;
        }
        if (attempt >= _maxRetries) {
          throw Exception('Cloudinary upload error after $_maxRetries attempts: $e');
        }
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    throw Exception('Upload failed after $_maxRetries attempts');
  }

  Future<Map<String, String>> uploadVideo(File videoFile) async {
    return uploadFile(videoFile, folder: 'reels');
  }

  Future<Map<String, String>> uploadProfilePic(File imageFile) async {
    return uploadFile(imageFile, folder: 'profiles');
  }

  Future<bool> deleteFile(String publicId) async {
    try {
      final response = await _dio.post(
        'https://api.cloudinary.com/v1_1/$cloudName/image/destroy',
        data: {
          'public_id': publicId,
          'upload_preset': uploadPreset,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

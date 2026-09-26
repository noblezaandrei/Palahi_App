import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../utils/error_messages.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(cloudName: 'lz6yw8ei', uploadPreset: 'Palahi');
});

class StorageService {
  final String cloudName;
  final String uploadPreset;

  StorageService({required this.cloudName, required this.uploadPreset});

  /// Uploads an [XFile] to Cloudinary.
  /// Returns the public image URL. Optional [onProgress] callback for progress monitoring.
  Future<String> uploadImage(
    XFile file,
    String path, {
    void Function(double progress)? onProgress,
  }) async {
    final bytes = await file.readAsBytes();
    return uploadBytes(bytes, path, onProgress: onProgress);
  }

  /// Uploads raw image bytes to Cloudinary.
  Future<String> uploadBytes(
    List<int> bytes,
    String path, {
    void Function(double progress)? onProgress,
  }) async {
    if (cloudName.trim().isEmpty ||
        uploadPreset.trim().isEmpty ||
        cloudName == 'your_cloud_name') {
      throw const AppException('Photo uploads are not set up yet.');
    }

    try {
      final folderSegments = path.split('/');
      final fileName = folderSegments.isNotEmpty
          ? folderSegments.last
          : 'upload.jpg';
      final folder = folderSegments.length > 1
          ? folderSegments.sublist(0, folderSegments.length - 1).join('/')
          : '';

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = folder
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            Uint8List.fromList(bytes),
            filename: fileName,
          ),
        );

      if (onProgress != null) {
        onProgress(0.1);
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw const AppException(
            'Photo upload timed out. Please check your internet connection.',
          );
        },
      );

      final responseBody = await streamedResponse.stream.bytesToString();
      final response = http.Response(responseBody, streamedResponse.statusCode);

      if (onProgress != null) {
        onProgress(response.statusCode == 200 ? 1.0 : 0.0);
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint(
          'Cloudinary upload failed: ${response.statusCode} ${response.body}',
        );
        throw const AppException(
          'The photo could not be uploaded. Please try a different photo.',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final secureUrl =
          decoded['secure_url'] as String? ?? decoded['url'] as String?;

      if (secureUrl == null || secureUrl.isEmpty) {
        debugPrint('Cloudinary response had no URL: ${response.body}');
        throw const AppException(
          'The photo could not be uploaded. Please try again.',
        );
      }

      return secureUrl;
    } on AppException {
      rethrow;
    } catch (e) {
      debugPrint('Cloudinary upload failed: $e');
      throw const AppException(
        "The photo couldn't be uploaded. Please check your internet "
        'connection and try again.',
      );
    }
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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
    try {
      final bytes = await file.readAsBytes();
      return await uploadBytes(bytes, path, onProgress: onProgress);
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
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
      throw Exception(
        'Cloudinary is not configured yet. Update storage_service.dart with your cloud name and upload preset.',
      );
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
          throw Exception(
            'Upload timed out. Please check your internet connection.',
          );
        },
      );

      final responseBody = await streamedResponse.stream.bytesToString();
      final response = http.Response(responseBody, streamedResponse.statusCode);

      if (onProgress != null) {
        onProgress(response.statusCode == 200 ? 1.0 : 0.0);
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Cloudinary upload failed: ${response.reasonPhrase} ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final secureUrl =
          decoded['secure_url'] as String? ?? decoded['url'] as String?;

      if (secureUrl == null || secureUrl.isEmpty) {
        throw Exception(
          'Cloudinary upload response did not include a valid URL.',
        );
      }

      return secureUrl;
    } catch (e) {
      throw Exception('Cloudinary upload failed: $e');
    }
  }
}

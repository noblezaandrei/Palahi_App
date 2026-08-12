import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(FirebaseStorage.instance);
});

class StorageService {
  final FirebaseStorage _storage;

  StorageService(this._storage);

  /// Uploads an [XFile] to a specific [path] in Firebase Storage.
  /// Returns the download URL. Optional [onProgress] callback for progress monitoring (0.0 to 1.0).
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

  /// Uploads raw image bytes to Firebase Storage. Optional [onProgress] callback.
  Future<String> uploadBytes(
    dynamic bytes,
    String path, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ref = _storage.ref().child(path);
      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          if (snapshot.totalBytes > 0) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            onProgress(progress);
          }
        });
      }

      final snapshot = await uploadTask.timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          uploadTask.cancel();
          throw Exception('Upload timed out. Please check your internet connection.');
        },
      );

      if (snapshot.state != TaskState.success) {
        throw Exception('Upload task ended with status: ${snapshot.state}');
      }

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Firebase Storage upload failed: $e');
    }
  }
}

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
  /// Returns the download URL.
  Future<String> uploadImage(XFile file, String path) async {
    try {
      final bytes = await file.readAsBytes();
      return await uploadBytes(bytes, path);
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Uploads raw image bytes to Firebase Storage.
  Future<String> uploadBytes(dynamic bytes, String path) async {
    try {
      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Firebase Storage upload failed: $e');
    }
  }
}

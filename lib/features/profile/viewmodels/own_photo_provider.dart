import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/repositories/auth_repository.dart';
import '../../breeder/repositories/breeder_repository.dart';

/// The signed-in user's own picture, as shown on their profile: a breeder's
/// farm photo, otherwise the profile photo they uploaded, otherwise their
/// Google photo. Empty if they have none.
final ownPhotoUrlProvider = Provider<String>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return '';
  final profile = ref.watch(currentUserProfileProvider).value;

  var url = profile?['imageUrl'] as String? ?? '';
  if (url.isEmpty) url = user.photoURL ?? '';

  if (profile?['role'] == 'breeder') {
    for (final b in ref.watch(breedersStreamProvider).value ?? const []) {
      if (b.id == user.uid) {
        if (b.imageUrl.isNotEmpty) url = b.imageUrl;
        break;
      }
    }
  }
  return url;
});

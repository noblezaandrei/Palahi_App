import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/repositories/account_deletion_repository.dart';
import '../../breeder/repositories/breeder_repository.dart';
import '../../breeder/repositories/breeding_request_repository.dart';
import '../../map/repositories/farmer_location_repository.dart';
import '../../profile/viewmodels/own_photo_provider.dart';
import '../repositories/chat_repository.dart';

/// The other participant's picture in [room], from [uid]'s point of view.
///
/// Normally it's the one stored on the room, which each person keeps current
/// for themselves ([OwnPhotoSync]). Until the other person's app has done
/// that, fall back to where [uid] is allowed to read their picture:
///   - a farmer: the breeder's public farm photo;
///   - a breeder: the farmer's map pin, or the photo on one of their
///     bookings (a farmer's own profile is private).
String chatPartnerPhoto(WidgetRef ref, ChatRoomModel room, String uid) {
  final stored = room.otherImageUrl(uid);
  if (stored.isNotEmpty) return stored;
  // A deleted account's photo may linger on old bookings; don't bring it
  // back.
  if (room.otherName(uid) == deletedUserName) return '';

  if (room.farmerId == uid) {
    for (final b in ref.watch(breedersStreamProvider).value ?? const []) {
      if (b.id == room.breederId) return b.imageUrl;
    }
    return '';
  }

  final pin = ref.watch(farmerLocationProvider(room.farmerId)).value;
  if (pin != null && pin.imageUrl.isNotEmpty) return pin.imageUrl;

  // Newest booking first, so the most recent photo wins.
  for (final booking
      in ref.watch(breederRequestsProvider(uid)).value ?? const []) {
    if (booking.farmerId == room.farmerId &&
        booking.farmerImageUrl.isNotEmpty) {
      return booking.farmerImageUrl;
    }
  }
  return '';
}

/// Keeps the signed-in user's own picture current on their chat rooms, at
/// most once per distinct picture/room set (it writes nothing when already
/// current).
class OwnPhotoSync {
  String? _lastKey;

  void run(WidgetRef ref, String uid, List<ChatRoomModel> rooms) {
    final photo = ref.read(ownPhotoUrlProvider);
    if (photo.isEmpty || rooms.isEmpty) return;
    final key = '$photo|${rooms.map((r) => r.id).join(',')}';
    if (key == _lastKey) return;
    _lastKey = key;
    ref.read(chatRepositoryProvider).syncOwnPhoto(uid, photo, rooms).catchError(
      (Object e) {
        _lastKey = null; // try again next time
        debugPrint('Failed to sync chat photo: $e');
      },
    );
  }
}

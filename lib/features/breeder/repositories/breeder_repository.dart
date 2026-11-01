import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/breeder_model.dart';
import '../../auth/repositories/auth_repository.dart';

final breederRepositoryProvider = Provider<BreederRepository>((ref) {
  return BreederRepository(FirebaseFirestore.instance);
});

final breedersStreamProvider = StreamProvider<List<BreederModel>>((ref) {
  // Re-subscribe on sign-in/out — otherwise a stream that was cut off by
  // a permission-denied error during logout stays cached empty forever.
  ref.watch(authStateProvider);
  return ref.watch(breederRepositoryProvider).getBreeders();
});

/// A breeder's current public photo, live from their farm profile, or
/// [fallback] (e.g. the photo saved on an old booking) when they have none.
/// Bookings copy the photo when they're made, so reading it from the booking
/// alone showed no photo, or an old one, after the breeder changed it.
String liveBreederPhoto(
  List<BreederModel>? breeders,
  String breederId, {
  String fallback = '',
}) {
  for (final b in breeders ?? const <BreederModel>[]) {
    if (b.id == breederId) return b.imageUrl.isNotEmpty ? b.imageUrl : fallback;
  }
  return fallback;
}

class BreederRepository {
  final FirebaseFirestore _firestore;

  BreederRepository(this._firestore);

  Stream<List<BreederModel>> getBreeders() async* {
    try {
      await for (final snapshot
          in _firestore.collection('breeders').snapshots()) {
        yield snapshot.docs
            .map((doc) => BreederModel.fromJson(doc.data(), doc.id))
            .toList();
      }
    } catch (error) {
      debugPrint('Failed to load breeders: $error');
      yield <BreederModel>[];
    }
  }

  Future<void> addBreeder(BreederModel breeder) async {
    await _firestore
        .collection('breeders')
        .doc(breeder.id)
        .set(breeder.toJson());
  }

  /// Puts [photoUrl] on the breeder's farm profile if it has no photo yet.
  /// A breeder who never set a farm photo still sees their profile or Google
  /// photo on their own profile screen, but farmers can't read that (the
  /// rules keep /users private), so to them the breeder had no photo at all.
  /// Never replaces a farm photo, and never creates a missing profile.
  Future<void> fillMissingPhoto(String breederId, String photoUrl) async {
    if (photoUrl.isEmpty) return;
    final ref = _firestore.collection('breeders').doc(breederId);
    final doc = await ref.get();
    if (!doc.exists) return;
    if ((doc.data()?['imageUrl'] as String? ?? '').isNotEmpty) return;
    await ref.update({'imageUrl': photoUrl});
  }

  // arrayUnion/arrayRemove rather than writing the whole list, so quick taps
  // on the availability calendar can't overwrite each other's changes.
  Future<void> addAvailableDates(String breederId, List<String> dates) =>
      _updateAvailability(breederId, FieldValue.arrayUnion(dates));

  Future<void> removeAvailableDate(String breederId, String date) =>
      _updateAvailability(breederId, FieldValue.arrayRemove([date]));

  Future<void> _updateAvailability(String breederId, FieldValue change) async {
    final ref = _firestore.collection('breeders').doc(breederId);
    try {
      await ref.update({'availableDates': change});
    } on FirebaseException catch (e) {
      // Some breeder accounts have no farm profile (breeders/{uid}) — e.g.
      // the second write of their sign-up failed. Updating a missing
      // document is refused (permission-denied under our rules, not-found
      // otherwise), so create the profile with the sign-up defaults instead.
      if (e.code != 'permission-denied' && e.code != 'not-found') rethrow;
      if ((await ref.get()).exists) rethrow;
      final user = await _firestore.collection('users').doc(breederId).get();
      final name = user.data()?['name'] as String? ?? '';
      await ref.set({
        ...newBreederProfile(breederId, name),
        'availableDates': change,
      }, SetOptions(merge: true));
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../breeder/repositories/breeding_request_repository.dart';

final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository>((
  ref,
) {
  return AccountDeletionRepository(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
    ref.watch(breedingRequestRepositoryProvider),
  );
});

/// What other people see in place of a deleted user's name.
const deletedUserName = 'Deleted user';

/// Permanently deletes the signed-in user's account and personal data.
///
/// Call [AuthRepository.reauthenticate] first — Firebase only deletes an
/// account whose sign-in is recent.
///
/// Deleted: profile, username, farm pin, breeder farm profile and stud pig
/// listings, favorites, notifications, and every chat message they sent.
/// Kept, because the other person relies on them, but without their name:
/// chat rooms (shown as "Deleted user") and the reviews they wrote (so
/// breeder ratings don't change). Bookings are kept as the other party's
/// transaction record; active ones are cancelled first so nobody is left
/// waiting on a deleted account.
class AccountDeletionRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final BreedingRequestRepository _bookings;

  AccountDeletionRepository(this._db, this._auth, this._bookings);

  Future<void> deleteAccount({void Function(String step)? onProgress}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'You are not signed in.',
      );
    }
    final uid = user.uid;
    void step(String message) => onProgress?.call(message);

    final profileRef = _db.collection('users').doc(uid);
    final profile = (await profileRef.get()).data();

    step('Cancelling your active bookings…');
    for (final side in ['farmerId', 'breederId']) {
      final bookings = await _db
          .collection('bookings')
          .where(side, isEqualTo: uid)
          .get();
      for (final booking in bookings.docs) {
        final status = booking.data()['status'];
        if (status == 'pending' || status == 'accepted') {
          // Also frees the time slot and notifies the other person.
          await _bookings.updateRequestStatus(booking.id, 'cancelled');
        }
      }
    }

    step('Deleting your messages…');
    final rooms = await _db
        .collection('chat_rooms')
        .where('participants', arrayContains: uid)
        .get();
    for (final room in rooms.docs) {
      final myMessages = await room.reference
          .collection('messages')
          .where('senderId', isEqualTo: uid)
          .get();
      await _deleteAll(myMessages.docs.map((d) => d.reference));

      final side = room.data()['farmerId'] == uid ? 'farmer' : 'breeder';
      await room.reference.update({
        '${side}Name': deletedUserName,
        '${side}ImageUrl': '',
        'lastMessage': 'This account was deleted.',
      });
    }

    step('Removing your name from your reviews…');
    final reviews = await _db
        .collection('reviews')
        .where('farmerId', isEqualTo: uid)
        .get();
    for (final review in reviews.docs) {
      try {
        await review.reference.update({'farmerName': deletedUserName});
      } on FirebaseException catch (e) {
        // Very old reviews can fail today's validation on update (e.g. a
        // missing pig rating); delete those rather than leave the name.
        debugPrint('Could not anonymize review ${review.id}: $e');
        await review.reference.delete();
      }
    }

    step('Deleting your listings and saved data…');
    final pigs = await _db
        .collection('stud_pigs')
        .where('breederId', isEqualTo: uid)
        .get();
    final favorites = await _db
        .collection('favorites')
        .where('userId', isEqualTo: uid)
        .get();
    final notifications = await _db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .get();
    await _deleteAll([
      ...pigs.docs.map((d) => d.reference),
      ...favorites.docs.map((d) => d.reference),
      ...notifications.docs.map((d) => d.reference),
      _db.collection('breeders').doc(uid),
      _db.collection('farmer_locations').doc(uid),
    ]);

    step('Deleting your profile…');
    final username = (profile?['username'] as String?)?.trim().toLowerCase();
    if (username != null && username.isNotEmpty) {
      try {
        await _db.collection('usernames').doc(username).delete();
      } on FirebaseException catch (e) {
        // Only frees the name for someone else; never block deletion on it.
        debugPrint('Could not release username "$username": $e');
      }
    }
    await profileRef.delete();

    step('Deleting your sign-in account…');
    await user.delete();
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (e) {
        debugPrint('Google sign-out after deletion failed: $e');
      }
    }
  }

  /// Deletes documents in batches (Firestore allows 500 writes per batch).
  /// Deleting a document that doesn't exist is fine.
  Future<void> _deleteAll(Iterable<DocumentReference> refs) async {
    final list = refs.toList();
    for (var i = 0; i < list.length; i += 450) {
      final batch = _db.batch();
      for (final ref in list.skip(i).take(450)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }
}

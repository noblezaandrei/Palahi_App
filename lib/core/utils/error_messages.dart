import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// An error whose message is already written for the user, so
/// [friendlyError] shows it as-is instead of a generic fallback.
class AppException implements Exception {
  final String message;

  const AppException(this.message);

  @override
  String toString() => message;
}

/// Thrown by [NetworkTimeout.withNetworkTimeout] when the server hasn't
/// answered in time.
class SlowNetworkException extends AppException {
  const SlowNetworkException()
    : super(
        'Your connection is slow or offline. This will finish on its own '
        'once you are back online.',
      );
}

/// How long a save waits for the server before the UI stops spinning.
const networkTimeout = Duration(seconds: 20);

extension NetworkTimeout<T> on Future<T> {
  /// Stops *waiting* after [networkTimeout] — the underlying Firestore write
  /// keeps going and is sent once the connection returns, so this only
  /// frees the UI (buttons used to spin forever while offline).
  Future<T> withNetworkTimeout() => timeout(
    networkTimeout,
    onTimeout: () => throw const SlowNetworkException(),
  );
}

/// Plain-language text for an error, for snackbars and error states —
/// instead of raw "[cloud_firestore/permission-denied] ..." strings. The
/// original error is still printed to the debug console.
String friendlyError(Object error) {
  debugPrint('Error shown to user: $error');

  if (error is AppException) return error.message;

  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'network-request-failed':
        return 'No internet connection. Please check your connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'An account already uses this email. Try logging in instead.';
      case 'weak-password':
        return 'That password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'requires-recent-login':
        return 'For your security, please log out and log in again first.';
      case 'invalid-credential':
      case 'wrong-password':
        return 'Incorrect password.';
      case 'user-mismatch':
        return "That's a different Google account. Choose the one you use "
            'for PALAHI.';
    }
    // The app's own codes (email-not-verified, username-already-in-use, ...)
    // carry a message written for the user.
    return error.message ?? 'Something went wrong. Please try again.';
  }

  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return "Can't reach the server. Please check your internet connection.";
      case 'permission-denied':
        return "You're not allowed to do that. If this keeps happening, "
            'log out and log in again.';
      case 'not-found':
        return 'This item no longer exists.';
      case 'resource-exhausted':
        return 'The app is busy right now. Please try again in a moment.';
    }
    return 'Something went wrong. Please try again.';
  }

  if (error is TimeoutException ||
      error is http.ClientException ||
      error.toString().contains('SocketException')) {
    return "Can't reach the server. Please check your internet connection.";
  }

  return 'Something went wrong. Please try again.';
}

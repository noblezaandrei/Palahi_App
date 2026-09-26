import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../repositories/auth_repository.dart';
import '../../../core/utils/error_messages.dart';

class LoginState {
  final bool isGoogleSigningIn;
  final bool isResending;

  const LoginState({this.isGoogleSigningIn = false, this.isResending = false});

  LoginState copyWith({bool? isGoogleSigningIn, bool? isResending}) {
    return LoginState(
      isGoogleSigningIn: isGoogleSigningIn ?? this.isGoogleSigningIn,
      isResending: isResending ?? this.isResending,
    );
  }
}

enum GoogleSignInStatus { signedIn, cancelled, failed }

class GoogleSignInResult {
  final GoogleSignInStatus status;
  final User? user;
  final String? errorMessage;

  const GoogleSignInResult(this.status, {this.user, this.errorMessage});
}

/// Logic behind the login screen's Google sign-in, password reset and
/// verification-email actions. The view owns only the dialogs, snackbars and
/// navigation.
class LoginViewModel extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  bool isGoogleUser(User user) =>
      user.providerData.any((info) => info.providerId == 'google.com');

  void setGoogleBusy(bool busy) {
    state = state.copyWith(isGoogleSigningIn: busy);
  }

  /// Runs the Google account chooser and sign-in. Leaves the busy flag on when
  /// it returns [GoogleSignInStatus.signedIn] — the caller finishes setup and
  /// then clears it with [setGoogleBusy].
  Future<GoogleSignInResult> signInWithGoogle() async {
    setGoogleBusy(true);
    try {
      final credential = await _repository.signInWithGoogle();
      final user = credential.user;
      if (user == null) {
        setGoogleBusy(false);
        return const GoogleSignInResult(GoogleSignInStatus.cancelled);
      }
      return GoogleSignInResult(GoogleSignInStatus.signedIn, user: user);
    } catch (error) {
      setGoogleBusy(false);

      // The account chooser was closed without picking anything.
      if (error is GoogleSignInException &&
          error.code == GoogleSignInExceptionCode.canceled) {
        return const GoogleSignInResult(GoogleSignInStatus.cancelled);
      }
      if (error is FirebaseAuthException &&
          (error.code == 'canceled' ||
              error.code == 'popup-closed-by-user' ||
              error.code == 'cancelled-popup-request' ||
              error.code == 'web-context-canceled')) {
        return const GoogleSignInResult(GoogleSignInStatus.cancelled);
      }

      // Some devices throw after the account was actually chosen even though
      // Firebase has signed them in — carry on rather than stranding them.
      final current = _repository.currentUser;
      if (current != null && isGoogleUser(current)) {
        setGoogleBusy(true);
        return GoogleSignInResult(GoogleSignInStatus.signedIn, user: current);
      }

      return GoogleSignInResult(
        GoogleSignInStatus.failed,
        errorMessage: friendlyError(error),
      );
    }
  }

  Future<bool> hasProfile(User user) => _repository.hasUserProfile(user.uid);

  Future<void> completeGoogleSignUp(User user, String role) {
    return _repository.completeGoogleSignUp(
      uid: user.uid,
      email: user.email ?? '',
      // Email sign-ups have no display name; the part before the @ beats a
      // generic placeholder, and can be changed in Edit Profile.
      name: user.displayName ?? user.email?.split('@').first ?? 'New User',
      role: role,
    );
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _repository.sendPasswordResetEmail(email);
  }

  Future<void> resendVerificationEmail(
    String identifier,
    String password,
  ) async {
    state = state.copyWith(isResending: true);
    try {
      await _repository.resendVerificationEmail(identifier, password);
    } finally {
      state = state.copyWith(isResending: false);
    }
  }
}

final loginViewModelProvider = NotifierProvider<LoginViewModel, LoginState>(
  LoginViewModel.new,
);

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(() {
  return AuthController();
});

class AuthController extends AsyncNotifier<void> {
  late final AuthRepository _authRepository;

  @override
  FutureOr<void> build() {
    _authRepository = ref.watch(authRepositoryProvider);
  }

  /// [identifier] is a username or an email — see
  /// [AuthRepository.resolveToEmail].
  Future<void> login(String identifier, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _authRepository.signInWithUsernameOrEmail(identifier, password),
    );
  }

  Future<void> register(
    String email,
    String password,
    String name,
    String role,
    String username,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _authRepository.registerWithEmailAndPassword(
        email,
        password,
        name,
        role,
        username,
      ),
    );
  }

  Future<void> logout() async {
    await _authRepository.signOut();
  }
}

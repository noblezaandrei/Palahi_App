import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/error_messages.dart';
import '../repositories/auth_repository.dart';
import '../viewmodels/auth_controller.dart';
import '../viewmodels/login_view_model.dart';
import 'widgets/role_selection_dialog.dart';

/// Shown instead of the home tabs when a signed-in user has no /users
/// profile — e.g. they closed the app at the Google sign-up role picker, or
/// the connection dropped partway through registering. Previously such
/// accounts were silently treated as farmers and could never save a profile.
class FinishSetupScreen extends ConsumerStatefulWidget {
  const FinishSetupScreen({super.key});

  @override
  ConsumerState<FinishSetupScreen> createState() => _FinishSetupScreenState();
}

class _FinishSetupScreenState extends ConsumerState<FinishSetupScreen> {
  bool _busy = false;

  Future<void> _continue() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    final vm = ref.read(loginViewModelProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      // The profile may exist after all and only failed to load (e.g. a
      // brief network error) — never overwrite it; just load it again.
      if (await vm.hasProfile(user).withNetworkTimeout()) {
        ref.invalidate(currentUserProfileProvider);
        return;
      }
      if (!mounted) return;
      final role = await showRoleSelectionDialog(context);
      if (role == null) return;
      // The profile stream picks up the new document and home rebuilds.
      await vm.completeGoogleSignUp(user, role).withNetworkTimeout();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logOut() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Finish setting up your account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  "Your account's setup didn't finish. Tell us whether you're "
                  'a farmer or a breeder to continue.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _continue,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Continue'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : _logOut,
                  child: const Text('Log out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

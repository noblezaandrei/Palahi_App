import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/error_messages.dart';
import '../../auth/repositories/account_deletion_repository.dart';
import '../../auth/repositories/auth_repository.dart';

/// Lets a user permanently delete their account and personal data, after
/// confirming who they are (password, or Google for Google accounts).
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _passwordController = TextEditingController();
  bool _understood = false;
  bool _passwordVisible = false;
  bool _deleting = false;
  String? _progress;
  String? _passwordError;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isGoogle => ref.read(authRepositoryProvider).isGoogleAccount;

  Future<void> _delete() async {
    if (!_isGoogle && _passwordController.text.trim().isEmpty) {
      setState(() => _passwordError = 'Enter your password to confirm.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your PALAHI account. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep my account'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Captured now: deleting signs the user out, which rebuilds the screens
    // underneath and can unmount this one before it finishes.
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _deleting = true;
      _passwordError = null;
      _progress = 'Confirming it’s you…';
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .reauthenticate(password: _passwordController.text);
      await ref
          .read(accountDeletionRepositoryProvider)
          .deleteAccount(
            onProgress: (step) {
              if (mounted) setState(() => _progress = step);
            },
          );
      router.go('/login');
      messenger.showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _progress = null;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Your account was not deleted: ${friendlyError(error)}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGoogle = _isGoogle;

    return PopScope(
      // Don't let the user back out halfway through deleting.
      canPop: !_deleting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Delete Account')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'Permanently delete your account',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                const _Section(
                  title: 'What gets deleted',
                  lines: [
                    'Your profile, photo, username and login',
                    'Your farm location pin',
                    'Your breeder farm profile and stud pig listings',
                    'Messages you sent, your favorites and notifications',
                  ],
                ),
                const SizedBox(height: 12),
                const _Section(
                  title: 'What stays, without your name',
                  lines: [
                    'Reviews you wrote, shown as "Deleted user", so breeder '
                        'ratings stay accurate',
                    'Chats show you as "Deleted user"; the other person '
                        'keeps their own messages',
                    'Booking records, which the other farmer or breeder '
                        'keeps as their transaction history. Pending and '
                        'accepted bookings are cancelled first.',
                  ],
                ),
                const SizedBox(height: 20),
                if (isGoogle)
                  const Text(
                    'To confirm it’s you, you’ll be asked to choose your '
                    'Google account.',
                  )
                else
                  TextField(
                    controller: _passwordController,
                    obscureText: !_passwordVisible,
                    enabled: !_deleting,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password to confirm',
                      errorText: _passwordError,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () => _passwordVisible = !_passwordVisible,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _understood,
                  onChanged: _deleting
                      ? null
                      : (value) => setState(() => _understood = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('I understand this cannot be undone.'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _understood && !_deleting ? _delete : null,
                    child: _deleting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Delete my account'),
                  ),
                ),
                if (_progress != null) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      _progress!,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<String> lines;

  const _Section({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(line)),
              ],
            ),
          ),
      ],
    );
  }
}

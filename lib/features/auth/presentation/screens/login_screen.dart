import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_controller.dart';
import '../../data/auth_repository.dart';
import '../../../../core/utils/validators.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isResending = false;
  bool _isGoogleSigningIn = false;
  String? _emailError;

  void _onEmailChanged(String value) {
    setState(() => _emailError = emailErrorText(value));
  }

  Future<void> _resendVerificationEmail() async {
    setState(() => _isResending = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resendVerificationEmail(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent. Please check your inbox.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    String? dialogError;
    bool isSending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              final email = resetEmailController.text.trim();
              if (!isValidEmail(email)) {
                setDialogState(
                  () => dialogError = 'Enter a valid email address',
                );
                return;
              }

              setDialogState(() {
                isSending = true;
                dialogError = null;
              });

              try {
                await ref
                    .read(authRepositoryProvider)
                    .sendPasswordResetEmail(email);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Password reset email sent. Please check your inbox.',
                      ),
                    ),
                  );
                }
              } on FirebaseAuthException catch (error) {
                setDialogState(() {
                  isSending = false;
                  dialogError = error.message ?? error.code;
                });
              } catch (error) {
                setDialogState(() {
                  isSending = false;
                  dialogError = error.toString();
                });
              }
            }

            return AlertDialog(
              title: const Text('Reset Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your email address and we\'ll send you a link to reset your password.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      errorText: dialogError,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSending
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSending ? null : submit,
                  child: isSending
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send Link'),
                ),
              ],
            );
          },
        );
      },
    );

    resetEmailController.dispose();
  }

  Future<String?> _showRoleSelectionDialog() {
    String selectedRole = 'farmer';

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Welcome!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tell us who you are so we can set up your account:',
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<String>(
                    groupValue: selectedRole,
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedRole = value);
                      }
                    },
                    child: const Column(
                      children: [
                        RadioListTile<String>(
                          title: Text('Farmer'),
                          value: 'farmer',
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<String>(
                          title: Text('Breeder'),
                          value: 'breeder',
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(selectedRole),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleSigningIn = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      final userCredential = await repository.signInWithGoogle();
      final user = userCredential.user;
      if (user == null) return;

      final hasProfile = await repository.hasUserProfile(user.uid);
      if (!hasProfile) {
        if (!mounted) return;
        final role = await _showRoleSelectionDialog();
        // Dialog is non-dismissible and always resolves to a role via
        // Continue, but guard anyway in case the widget got disposed.
        if (role == null) return;

        await repository.completeGoogleSignUp(
          uid: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? 'New User',
          role: role,
        );
      }

      if (mounted) context.go('/home');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _isGoogleSigningIn = false);
    }
  }

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (!isValidEmail(email)) {
      setState(() => _emailError = 'Enter a valid email address');
      return;
    }

    await ref.read(authControllerProvider.notifier).login(email, password);
  }

  @override
  Widget build(BuildContext context) {
    // Listen for auth state changes to show errors or navigate
    ref.listen<AsyncValue<void>>(authControllerProvider, (_, state) {
      state.whenOrNull(
        error: (error, stackTrace) {
          final isUnverified =
              error is FirebaseAuthException &&
              error.code == 'email-not-verified';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isUnverified
                    ? error.message ?? error.toString()
                    : error.toString(),
              ),
              action: isUnverified
                  ? SnackBarAction(
                      label: 'Resend',
                      onPressed: _resendVerificationEmail,
                    )
                  : null,
            ),
          );
        },
        data: (_) {
          // Successfully logged in, router will handle redirect or we can push
          context.go('/home');
        },
      );
    });

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading || _isResending || _isGoogleSigningIn;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome Back!',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Login to continue',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: _onEmailChanged,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  errorText: _emailError,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isLoading ? null : _showForgotPasswordDialog,
                  child: const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isLoading ? null : _login,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Login'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OR',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: isLoading ? null : _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _isGoogleSigningIn
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign in with Google'),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            context.push('/register');
                          },
                    child: const Text('Register'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

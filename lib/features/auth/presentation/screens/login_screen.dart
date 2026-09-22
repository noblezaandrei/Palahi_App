import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../providers/auth_controller.dart';
import '../../data/auth_repository.dart';
import '../../../../core/utils/validators.dart';

// Google's published brand values for the light-theme sign-in button.
const Color _googleBorderColor = Color(0xFF747775);
const Color _googleTextColor = Color(0xFF1F1F1F);

// The official four-color Google "G". Inlined rather than shipped as an
// asset so the button stays self-contained.
const String _googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
  <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
  <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
  <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>
''';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isResending = false;
  bool _isGoogleSigningIn = false;
  String? _identifierError;

  // The field takes a username or an email, so it can only be validated as
  // an email once it actually looks like one — a username in progress
  // shouldn't be flagged as a malformed address.
  void _onIdentifierChanged(String value) {
    setState(() {
      _identifierError = value.contains('@') ? emailErrorText(value) : null;
    });
  }

  Future<void> _resendVerificationEmail() async {
    setState(() => _isResending = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resendVerificationEmail(
            _identifierController.text.trim(),
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
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showForgotPasswordDialog() async {
    // Password resets go through Firebase's own email flow, so this always
    // asks for an email even when they logged in with a username. Only
    // prefill it if what they typed already looks like one.
    final typed = _identifierController.text.trim();
    final resetEmailController = TextEditingController(
      text: typed.contains('@') ? typed : '',
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

  bool _finishingGoogleSignIn = false;

  bool _isGoogleUser(User user) =>
      user.providerData.any((info) => info.providerId == 'google.com');

  /// Takes a freshly signed-in Google user the rest of the way: role setup
  /// for first-timers, then the homepage. Reachable from both the sign-in
  /// call returning and the auth-state listener, since on some devices the
  /// Google flow signs the user in but the call never resolves — so it's
  /// guarded to run only once.
  Future<void> _finishGoogleSignIn(User user) async {
    if (_finishingGoogleSignIn) return;
    _finishingGoogleSignIn = true;
    if (mounted) setState(() => _isGoogleSigningIn = true);
    try {
      final repository = ref.read(authRepositoryProvider);
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
      _finishingGoogleSignIn = false;
      if (mounted) setState(() => _isGoogleSigningIn = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleSigningIn = true);
    try {
      final userCredential = await ref
          .read(authRepositoryProvider)
          .signInWithGoogle();
      final user = userCredential.user;
      if (user == null) {
        if (mounted) setState(() => _isGoogleSigningIn = false);
        return;
      }
      await _finishGoogleSignIn(user);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isGoogleSigningIn = false);

      // The account chooser was closed without picking anything.
      if (error is GoogleSignInException &&
          error.code == GoogleSignInExceptionCode.canceled) {
        return;
      }
      if (error is FirebaseAuthException &&
          (error.code == 'canceled' ||
              error.code == 'popup-closed-by-user' ||
              error.code == 'cancelled-popup-request' ||
              error.code == 'web-context-canceled')) {
        return;
      }

      // Some devices throw after the account was actually chosen even though
      // Firebase has signed them in — carry on rather than stranding them.
      final current = ref.read(authRepositoryProvider).currentUser;
      if (current != null && _isGoogleUser(current)) {
        await _finishGoogleSignIn(current);
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _login() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (identifier.contains('@') && !isValidEmail(identifier)) {
      setState(() => _identifierError = 'Enter a valid email address');
      return;
    }

    await ref.read(authControllerProvider.notifier).login(identifier, password);
  }

  @override
  Widget build(BuildContext context) {
    // Google sign-in proceeds as soon as Firebase reports the account, without
    // waiting on the sign-in call itself to return.
    ref.listen<AsyncValue<User?>>(authStateProvider, (_, state) {
      final user = state.value;
      if (user != null && _isGoogleUser(user)) _finishGoogleSignIn(user);
    });

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
                controller: _identifierController,
                autocorrect: false,
                onChanged: _onIdentifierChanged,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter your username',
                  errorText: _identifierError,
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
              // Google's branding guidelines require their own colors, logo
              // and typeface on this button rather than the host app's
              // palette, so it deliberately overrides the app theme.
              OutlinedButton(
                onPressed: isLoading ? null : _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _googleTextColor,
                  side: const BorderSide(color: _googleBorderColor),
                  minimumSize: const Size.fromHeight(48),
                  textStyle: GoogleFonts.roboto(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                child: _isGoogleSigningIn
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.string(
                            _googleLogoSvg,
                            height: 20,
                            width: 20,
                          ),
                          const SizedBox(width: 12),
                          const Text('Sign in with Google'),
                        ],
                      ),
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

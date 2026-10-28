import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../viewmodels/auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/pig_icon.dart';
import 'widgets/role_card.dart';
import '../../../core/utils/validators.dart';
import 'package:palahi/core/utils/error_messages.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  // The auth controller is shared with the Login screen underneath, so only
  // react to results of a registration started here.
  bool _registerInFlight = false;
  String _selectedRole = 'farmer';
  String? _emailError;
  String? _usernameError;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onEmailChanged(String value) {
    setState(() => _emailError = emailErrorText(value));
  }

  void _onUsernameChanged(String value) {
    setState(() => _usernameError = usernameErrorText(value));
  }

  void _register() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty ||
        username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (!isValidUsername(username)) {
      setState(
        () => _usernameError =
            usernameErrorText(username) ?? 'Enter a valid username',
      );
      return;
    }

    if (!isValidEmail(email)) {
      setState(() => _emailError = 'Enter a valid email address');
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    FocusScope.of(context).unfocus();
    _registerInFlight = true;
    await ref
        .read(authControllerProvider.notifier)
        .register(email, password, name, _selectedRole, username);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(authControllerProvider, (_, state) {
      // Only react to a registration started on this screen.
      if (!_registerInFlight || !mounted || state.isLoading) return;
      _registerInFlight = false;
      state.whenOrNull(
        error: (error, stackTrace) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
        },
        data: (_) async {
          final messenger = ScaffoldMessenger.of(context);
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Registration successful! We sent a verification link to your email — please verify it before logging in.',
              ),
              duration: Duration(seconds: 5),
            ),
          );

          // Sign out because Firebase automatically logs in a newly created user
          await ref.read(authControllerProvider.notifier).logout();

          if (context.mounted) {
            context.go('/login');
          }
        },
      );
    });

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return AuthScaffold(
      title: 'Create account',
      subtitle: 'Join PALAHI in a few quick steps',
      onBack: () => context.pop(),
      children: [
        Text(
          'I am a',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: RoleCard(
                label: 'Farmer',
                caption: 'Book stud pigs',
                icon: const Icon(Icons.agriculture_outlined, size: 30),
                selected: _selectedRole == 'farmer',
                onTap: () => setState(() => _selectedRole = 'farmer'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RoleCard(
                label: 'Breeder',
                caption: 'Offer stud pigs',
                icon: const PigIcon(size: 30),
                selected: _selectedRole == 'breeder',
                onTap: () => setState(() => _selectedRole = 'breeder'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _nameController,
          inputFormatters: [LengthLimitingTextInputFormatter(60)],
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            hintText: 'Enter your full name',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _usernameController,
          inputFormatters: [LengthLimitingTextInputFormatter(20)],
          onChanged: _onUsernameChanged,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Username',
            hintText: 'Choose a username to log in with',
            prefixIcon: const Icon(Icons.person_outline_rounded),
            errorText: _usernameError,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          inputFormatters: [LengthLimitingTextInputFormatter(254)],
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          onChanged: _onEmailChanged,
          decoration: InputDecoration(
            labelText: 'Email',
            hintText: 'Enter your email',
            prefixIcon: const Icon(Icons.mail_outline_rounded),
            errorText: _emailError,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Create a password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: _visibilityToggle(
              _isPasswordVisible,
              () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: !_isConfirmPasswordVisible,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!isLoading) _register();
          },
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            hintText: 'Confirm your password',
            prefixIcon: const Icon(Icons.lock_reset_rounded),
            suffixIcon: _visibilityToggle(
              _isConfirmPasswordVisible,
              () => setState(
                () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        AuthPrimaryButton(
          label: 'Create Account',
          loading: isLoading,
          onPressed: isLoading ? null : _register,
        ),
        const SizedBox(height: 12),
        AuthFooterLink(
          prompt: 'Already have an account?',
          action: 'Log In',
          onTap: isLoading ? null : () => context.pop(),
        ),
      ],
    );
  }

  Widget _visibilityToggle(bool visible, VoidCallback onPressed) => IconButton(
    tooltip: visible ? 'Hide password' : 'Show password',
    icon: Icon(
      visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
    ),
    onPressed: onPressed,
  );
}

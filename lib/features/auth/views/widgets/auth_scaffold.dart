import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/colors.dart';

/// The shared look of the login and register screens, matching the intro:
/// a green header with the logo and PALAHI, and the form on a white sheet
/// that overlaps it.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  /// Shows a back arrow in the header (register, which sits on top of login).
  final VoidCallback? onBack;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.onBack,
  });

  static const _headerDark = Color(0xFF1B5E20);

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _header(topInset),
            Transform.translate(
              offset: const Offset(0, -36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(28),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(double topInset) => Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 64),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [_headerDark, AppColors.primary, Color(0xFF43A047)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
    ),
    child: Stack(
      children: [
        // Soft light circles, like the intro's background.
        Positioned(top: -40, right: -50, child: _ring(170, 22)),
        Positioned(bottom: -70, left: -40, child: _ring(150, 14)),
        Column(
          children: [
            SizedBox(
              height: 44,
              child: Align(
                alignment: Alignment.centerLeft,
                child: onBack == null
                    ? null
                    : IconButton(
                        onPressed: onBack,
                        tooltip: 'Back',
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(45),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'PALAHI',
              style: GoogleFonts.poppins(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 7,
                height: 1.1,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _ring(double size, int alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withAlpha(alpha),
    ),
  );
}

/// The main green action button of the auth screens, with a spinner while
/// [loading].
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled || loading ? 1 : 0.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF43A047)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(60),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.4,
                  ),
                )
              : Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
        ),
      ),
    );
  }
}

/// "Don't have an account? Register"-style footer line.
class AuthFooterLink extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback? onTap;

  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          prompt,
          style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textLight),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 36),
          ),
          child: Text(action),
        ),
      ],
    );
  }
}

/// A thin "OR" divider between the main login and Google sign-in.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textLight,
              letterSpacing: 1,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.divider)),
      ],
    );
  }
}

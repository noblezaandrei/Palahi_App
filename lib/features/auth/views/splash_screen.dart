import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../repositories/auth_repository.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/app_version_text.dart';
import '../../../core/widgets/pig_loader.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _route();
  }

  /// Where Get Started leads: home when already signed in, otherwise the
  /// login form. Null while the saved login is still being checked.
  String? _next;

  Future<void> _route() async {
    // Long enough for the logo intro to play, short enough not to drag.
    final minSplash = Future.delayed(const Duration(milliseconds: 1200));
    final repository = ref.read(authRepositoryProvider);
    // The first auth event arrives once the saved login has been restored,
    // so a signed-in user is never mistaken for signed out.
    User? user;
    try {
      user = await repository.authStateChanges.first.timeout(
        const Duration(seconds: 3),
      );
    } catch (_) {
      user = repository.currentUser;
    }

    // Only an unverified user needs a server refresh (to see if they've
    // verified since). A verified session is trusted from cache, so opening
    // the app doesn't wait on the network.
    if (user != null && !user.emailVerified) {
      // reload() throws when offline or if the account was deleted or
      // disabled — uncaught, that left the app stuck on this screen. Fall
      // back to the cached session instead. The timeout keeps a slow
      // connection from holding the splash screen up.
      try {
        await user.reload().timeout(const Duration(seconds: 4));
        user = repository.currentUser;
      } catch (e) {
        debugPrint('Could not refresh session: $e');
      }
    }

    if (user != null && !user.emailVerified) {
      // Signed in but never verified their email — don't let them in.
      await repository.signOut();
    }

    await minSplash;
    if (!mounted) return;
    // The intro stays up until the user taps Get Started.
    setState(
      () => _next = user != null && user.emailVerified ? '/home' : '/login',
    );
  }

  // Plays once: the logo pops in, then the PALAHI name rises in after
  // it, then the loader (and later Get Started) fades in. The logo keeps gently floating after.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _intro.dispose();
    _float.dispose();
    super.dispose();
  }

  /// [_intro] narrowed to the part of it between [start] and [end] (0–1).
  Animation<double> _step(
    double start,
    double end, [
    Curve curve = Curves.easeOutCubic,
  ]) => CurvedAnimation(
    parent: _intro,
    curve: Interval(start, end, curve: curve),
  );

  Widget _riseIn(Animation<double> animation, Widget child) => FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.4),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final logoIn = _step(0, 0.55, Curves.elasticOut);
    final logoFade = _step(0, 0.25);
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, AppColors.primaryBackground],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // Soft green circles in the corners, for depth.
            Positioned(
              top: -size.width * 0.35,
              right: -size.width * 0.3,
              child: _blob(size.width * 0.9, AppColors.primaryLighter, 70),
            ),
            Positioned(
              bottom: -size.width * 0.45,
              left: -size.width * 0.35,
              child: _blob(size.width * 1.0, AppColors.primaryLight, 45),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _floating(
                            FadeTransition(
                              opacity: logoFade,
                              child: ScaleTransition(
                                scale: Tween(
                                  begin: 0.4,
                                  end: 1.0,
                                ).animate(logoIn),
                                child: _logoCard(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          _riseIn(_step(0.3, 0.65), _wordmark()),
                          const SizedBox(height: 14),
                          _riseIn(
                            _step(0.4, 0.75),
                            Container(
                              width: 44,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    FadeTransition(
                      opacity: _step(0.7, 1),
                      child: SizedBox(
                        height: 56,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: _next == null
                              ? const PigLoader(size: 40)
                              : _getStartedButton(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppVersionText(
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Keeps [child] gently bobbing up and down.
  Widget _floating(Widget child) => AnimatedBuilder(
    animation: _float,
    builder: (context, child) => Transform.translate(
      offset: Offset(0, -6 * Curves.easeInOut.transform(_float.value)),
      child: child,
    ),
    child: child,
  );

  Widget _blob(double size, Color color, int alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [color.withAlpha(alpha), color.withAlpha(0)],
      ),
    ),
  );

  /// The logo with rounded corners and a soft green glow (no frame).
  Widget _logoCard() => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(38),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withAlpha(70),
          blurRadius: 40,
          offset: const Offset(0, 18),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(38),
      child: Image.asset(
        'assets/images/logo.png',
        width: 156,
        height: 156,
        fit: BoxFit.cover,
      ),
    ),
  );

  /// "PALAHI" in large letters with a green gradient.
  Widget _wordmark() => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (bounds) => const LinearGradient(
      colors: [Color(0xFF1B5E20), AppColors.primary, AppColors.primaryLight],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(bounds),
    child: Text(
      'PALAHI',
      style: GoogleFonts.poppins(
        fontSize: 52,
        fontWeight: FontWeight.w800,
        letterSpacing: 8,
        height: 1.0,
      ),
    ),
  );

  Widget _getStartedButton() => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(
        colors: [AppColors.primary, Color(0xFF43A047)],
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withAlpha(70),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => context.go(_next!),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Get Started',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_rounded, size: 22),
          ],
        ),
      ),
    ),
  );
}

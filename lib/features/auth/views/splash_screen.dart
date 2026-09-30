import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../../../core/constants/colors.dart';
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

    await minSplash;
    if (!mounted) return;

    if (user != null && user.emailVerified) {
      context.go('/home');
      return;
    }

    if (user != null) {
      // Signed in but never verified their email — don't let them in.
      await repository.signOut();
    }

    if (!mounted) return;
    context.go('/login');
  }

  // Plays once: the logo pops in, then the name and tagline rise in after
  // it, then the loader fades in. The logo keeps gently floating after.
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _float,
              builder: (context, child) => Transform.translate(
                offset: Offset(
                  0,
                  -6 * Curves.easeInOut.transform(_float.value),
                ),
                child: child,
              ),
              child: FadeTransition(
                opacity: logoFade,
                child: ScaleTransition(
                  scale: Tween(begin: 0.4, end: 1.0).animate(logoIn),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(60),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 124,
                        height: 124,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _riseIn(
              _step(0.3, 0.65),
              Text(
                'PALAHI',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _riseIn(
              _step(0.45, 0.8),
              Text(
                'Find Trusted Stud Pig Breeders Near You',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textLight),
              ),
            ),
            const SizedBox(height: 48),
            FadeTransition(
              opacity: _step(0.7, 1),
              child: const PigLoader(size: 40),
            ),
          ],
        ),
      ),
    );
  }
}

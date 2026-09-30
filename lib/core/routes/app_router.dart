import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/views/splash_screen.dart';
import '../../features/auth/views/login_screen.dart';
import '../../features/auth/views/register_screen.dart';
import '../../features/home/views/home_screen.dart';
import '../../features/breeder/views/breeder_detail_screen.dart';
import '../../features/breeder/views/manage_stud_pig_screen.dart';
import '../../features/breeder/views/breeding_requests_screen.dart';
import '../../features/breeder/views/reviews_screen.dart';
import '../../features/communication/views/notifications_screen.dart';
import '../../features/communication/views/messaging_screen.dart';
import '../../features/tracker/views/breeding_tracker_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _fade(state, const SplashScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _fade(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => _fade(state, const RegisterScreen()),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) => _fade(state, const HomeScreen()),
      ),
      GoRoute(
        path: '/breeder/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BreederDetailScreen(breederId: id);
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/messages',
        builder: (context, state) => const MessagingScreen(),
      ),
      GoRoute(
        path: '/manage-pig',
        builder: (context, state) {
          return const ManageStudPigScreen();
        },
      ),
      GoRoute(
        path: '/breeding-requests',
        builder: (context, state) => const BreedingRequestsScreen(),
      ),
      GoRoute(
        path: '/breeding-tracker',
        builder: (context, state) => const BreedingTrackerScreen(),
      ),
      GoRoute(
        path: '/reviews/:breederId',
        builder: (context, state) {
          final breederId = state.pathParameters['breederId']!;
          return ReviewsScreen(breederId: breederId);
        },
      ),
    ],
  );

  /// A soft cross-fade for the app's top-level screens (splash, login,
  /// register, home), which replace each other rather than stack.
  static Page<void> _fade(GoRouterState state, Widget child) =>
      CustomTransitionPage<void>(
        key: state.pageKey,
        child: child,
        transitionDuration: const Duration(milliseconds: 450),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            ),
      );
}

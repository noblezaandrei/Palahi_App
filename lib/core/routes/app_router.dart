import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/breeder/presentation/screens/breeder_detail_screen.dart';
import '../../features/breeder/presentation/screens/manage_stud_pig_screen.dart';
import '../../features/breeder/presentation/screens/breeding_requests_screen.dart';
import '../../features/breeder/presentation/screens/reviews_screen.dart';
import '../../features/communication/presentation/screens/notifications_screen.dart';
import '../../features/communication/presentation/screens/messaging_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
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
        path: '/reviews/:breederId',
        builder: (context, state) {
          final breederId = state.pathParameters['breederId']!;
          return ReviewsScreen(breederId: breederId);
        },
      ),
    ],
  );
}

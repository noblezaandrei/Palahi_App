import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () async {
      final repository = ref.read(authRepositoryProvider);
      var user = repository.currentUser;

      if (user != null) {
        await user.reload();
        user = repository.currentUser;
      }

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'PALAHI',
              style: Theme.of(
                context,
              ).textTheme.displayMedium?.copyWith(color: Colors.green),
            ),
            const SizedBox(height: 8),
            Text(
              'Find Trusted Stud Pig Breeders Near You',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Loading...'),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/presentation/providers/auth_controller.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../../../features/map/presentation/screens/map_screen.dart';
import '../../../../features/breeder/presentation/screens/breeder_list_screen.dart';
import '../../../../features/breeder/presentation/screens/breeding_requests_screen.dart';
import '../../../../features/breeder/presentation/screens/breeder_dashboard_screen.dart';
import '../../../../features/breeder/presentation/screens/my_pigs_screen.dart';
import '../../../../features/profile/presentation/screens/profile_screen.dart';
import '../../../../features/profile/presentation/screens/favorites_screen.dart';
import 'farmer_dashboard_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(currentUserProfileProvider);

    return userProfileAsync.when(
      data: (profile) {
        final role = profile?['role'] ?? 'farmer';

        List<Widget> screens;
        List<BottomNavigationBarItem> navItems;

        if (role == 'breeder') {
          screens = [
            const BreederDashboardScreen(),
            const MyPigsScreen(),
            const BreedingRequestsScreen(),
            const ProfileScreen(),
          ];
          navItems = const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.pets), label: 'My Pigs'),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment),
              label: 'Requests',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ];
        } else {
          // Farmer
          screens = [
            const FarmerDashboardScreen(),
            const MapScreen(),
            const BreederListScreen(),
            const FavoritesScreen(),
            const ProfileScreen(),
          ];
          navItems = const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Breeders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite),
              label: 'Favorites',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ];
        }

        // Prevent crash if role changes and index is out of bounds
        final safeIndex = _currentIndex < screens.length ? _currentIndex : 0;

        return Scaffold(
          appBar: (role == 'farmer' && safeIndex == 1) // MapScreen has its own AppBar
              ? null
              : AppBar(
                  title: const Text('PALAHI'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () {
                        context.push('/notifications');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () async {
                        await ref.read(authControllerProvider.notifier).logout();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                    ),
                  ],
                ),
          body: IndexedStack(index: safeIndex, children: screens),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: safeIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            items: navItems,
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(body: Center(child: Text('Error loading profile: $error'))),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palahi/features/auth/repositories/auth_repository.dart';
import 'package:palahi/features/map/views/map_screen.dart';
import 'package:palahi/features/breeder/views/breeder_list_screen.dart';
import 'package:palahi/features/breeder/views/breeding_requests_screen.dart';
import 'package:palahi/features/breeder/views/my_pigs_screen.dart';
import 'package:palahi/features/breeder/views/manage_availability_screen.dart';
import 'package:palahi/features/profile/views/profile_screen.dart';
import 'package:palahi/features/profile/views/favorites_screen.dart';
import 'package:palahi/features/communication/repositories/notification_repository.dart';
import 'package:palahi/core/widgets/badge_icon_button.dart';
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
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid;

    return userProfileAsync.when(
      data: (profile) {
        final role = profile?['role'] ?? 'farmer';
        final unreadMessages = uid == null
            ? 0
            : ref.watch(unreadChatNotificationCountProvider(uid)).value ?? 0;
        final unreadNotifications = uid == null
            ? 0
            : ref.watch(unreadNotificationCountProvider(uid)).value ?? 0;

        List<Widget> screens;
        List<BottomNavigationBarItem> navItems;

        if (role == 'breeder') {
          screens = [
            const MyPigsScreen(),
            const BreedingRequestsScreen(embeddedInTabs: true),
            const ManageAvailabilityScreen(embeddedInTabs: true),
            const ProfileScreen(),
          ];
          navItems = [
            // The app logo instead of a generic paw, dimmed when not selected.
            BottomNavigationBarItem(
              icon: Opacity(opacity: 0.55, child: _logoIcon()),
              activeIcon: _logoIcon(),
              label: 'My Pigs',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.assignment),
              label: 'Requests',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month),
              label: 'Calendar',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
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
        // Profile is always the last tab for both roles, and renders its
        // own green header with these same action buttons built in.
        final isProfileTab = safeIndex == screens.length - 1;

        return Scaffold(
          appBar:
              (role == 'farmer' && (safeIndex == 0 || safeIndex == 1)) ||
                  isProfileTab
              ? null
              : AppBar(
                  // Breeders and Favorites render inside this Scaffold, so
                  // the tab's name lives here rather than in a second AppBar
                  // of their own.
                  title: role == 'breeder'
                      ? null
                      : Text(
                          safeIndex == 2
                              ? 'Breeders'
                              : safeIndex == 3
                              ? 'Saved Breeders'
                              : 'PALAHI',
                        ),
                  actions: [
                    BadgeIconButton(
                      icon: Icons.chat_bubble_outline,
                      count: unreadMessages,
                      onPressed: () {
                        context.push('/messages');
                      },
                    ),
                    BadgeIconButton(
                      icon: Icons.notifications_outlined,
                      count: unreadNotifications,
                      onPressed: () {
                        context.push('/notifications');
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
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) {
        debugPrint('Profile load failed: $error');

        final fallbackScreens = [
          const FarmerDashboardScreen(),
          const MapScreen(),
          const BreederListScreen(),
          const FavoritesScreen(),
          const ProfileScreen(),
        ];

        final fallbackNavItems = const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Breeders'),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text('PALAHI'),
            actions: [
              BadgeIconButton(
                icon: Icons.notifications_outlined,
                count: uid == null
                    ? 0
                    : ref.watch(unreadNotificationCountProvider(uid)).value ??
                          0,
                onPressed: () {
                  context.push('/notifications');
                },
              ),
            ],
          ),
          // Taps update _currentIndex, so both must read it — hardcoding 0
          // left every tab button doing nothing on this fallback screen.
          body: IndexedStack(
            index: _currentIndex < fallbackScreens.length ? _currentIndex : 0,
            children: fallbackScreens,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex < fallbackScreens.length
                ? _currentIndex
                : 0,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            items: fallbackNavItems,
          ),
        );
      },
    );
  }

  Widget _logoIcon() => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: Image.asset(
      'assets/images/logo.png',
      width: 26,
      height: 26,
      fit: BoxFit.cover,
    ),
  );
}

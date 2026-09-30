import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palahi/features/auth/repositories/auth_repository.dart';
import 'package:palahi/features/auth/views/finish_setup_screen.dart';
import 'package:palahi/features/map/views/map_screen.dart';
import 'package:palahi/features/breeder/views/breeder_list_screen.dart';
import 'package:palahi/features/breeder/views/breeding_requests_screen.dart';
import 'package:palahi/features/breeder/views/my_pigs_screen.dart';
import 'package:palahi/features/breeder/views/manage_availability_screen.dart';
import 'package:palahi/features/profile/views/profile_screen.dart';
import 'package:palahi/features/profile/views/favorites_screen.dart';
import 'package:palahi/features/communication/repositories/notification_repository.dart';
import 'package:palahi/core/widgets/badge_icon_button.dart';
import 'package:palahi/features/communication/repositories/chat_repository.dart';
import 'package:palahi/features/communication/viewmodels/chat_photos.dart';
import 'package:palahi/features/profile/viewmodels/own_photo_provider.dart';
import 'farmer_dashboard_screen.dart';
import 'package:palahi/core/widgets/pig_loader.dart';
import 'package:palahi/core/services/push_notification_service.dart';
import 'package:palahi/core/l10n/app_strings.dart';
import 'package:palahi/core/services/local_notification_service.dart';
import 'package:palahi/features/breeder/repositories/breeding_request_repository.dart';
import 'package:palahi/features/tracker/repositories/breeding_record_repository.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // Fades the newly picked tab in. The tabs stay alive in an IndexedStack,
  // so this only animates — nothing reloads.
  late final AnimationController _tabFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: 1,
  );

  void _selectTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _tabFade.forward(from: 0);
  }

  @override
  void dispose() {
    _tabFade.dispose();
    super.dispose();
  }

  final _photoSync = OwnPhotoSync();

  @override
  void initState() {
    super.initState();
    // Keep this user's picture current on their chats, so the other person
    // sees it without this user having to open Messages first. Listeners
    // rather than watch, so a new chat message doesn't rebuild Home.
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    // Send this user's notifications to this phone as pushes.
    PushNotifications.start(uid);
    _startLocalNotifications(uid);
    void sync() {
      final rooms = ref.read(chatRoomsStreamProvider(uid)).value;
      if (rooms != null) _photoSync.run(ref, uid, rooms);
    }

    ref.listenManual(
      chatRoomsStreamProvider(uid),
      (_, _) => sync(),
      fireImmediately: true,
    );
    ref.listenManual(
      ownPhotoUrlProvider,
      (_, _) => sync(),
      fireImmediately: true,
    );
  }

  final _instantAlerts = InstantAlerts();

  /// Free, on-phone notifications: reminders scheduled from this user's
  /// bookings and breeding records (re-planned whenever those change), and
  /// new notifications shown as they arrive while the app is running.
  void _startLocalNotifications(String uid) {
    void plan() {
      LocalNotifications.syncReminders(
        planReminders(
          uid: uid,
          bookings: [
            ...?ref.read(farmerRequestsProvider(uid)).value,
            ...?ref.read(breederRequestsProvider(uid)).value,
          ],
          records: ref.read(farmerBreedingRecordsProvider(uid)).value ?? {},
          now: DateTime.now(),
        ),
      );
    }

    LocalNotifications.start().then((_) => plan());
    ref.listenManual(farmerRequestsProvider(uid), (_, _) => plan());
    ref.listenManual(breederRequestsProvider(uid), (_, _) => plan());
    ref.listenManual(farmerBreedingRecordsProvider(uid), (_, _) => plan());
    ref.listenManual(userNotificationsProvider(uid), (_, next) {
      final list = next.value;
      if (list != null) _instantAlerts.onNotifications(list);
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid;

    return userProfileAsync.when(
      data: (profile) {
        // No profile document: finish setup instead of guessing a role.
        if (profile == null) return const FinishSetupScreen();
        final role = profile['role'] ?? 'farmer';
        final unreadMessages = uid == null
            ? 0
            : ref.watch(unreadChatNotificationCountProvider(uid)).value ?? 0;
        final unreadNotifications = uid == null
            ? 0
            : ref.watch(unreadNotificationCountProvider(uid)).value ?? 0;

        List<Widget> screens;
        List<NavigationDestination> navItems;

        if (role == 'breeder') {
          screens = [
            const MyPigsScreen(),
            const BreedingRequestsScreen(embeddedInTabs: true),
            const ManageAvailabilityScreen(embeddedInTabs: true),
            const ProfileScreen(),
          ];
          navItems = [
            // The app logo instead of a generic paw, dimmed when not selected.
            NavigationDestination(
              icon: Opacity(opacity: 0.55, child: _logoIcon()),
              selectedIcon: _logoIcon(),
              label: tr('My Pigs'),
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: tr('Requests'),
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: tr('Calendar'),
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: tr('Profile'),
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
          navItems = [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: tr('Home'),
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: tr('Map'),
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: tr('Breeders'),
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite),
              label: tr('Favorites'),
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: tr('Profile'),
            ),
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
                  // Each tab names itself in its green header card, the same
                  // for farmers and breeders, so the bar only holds the
                  // message and notification buttons.
                  title: null,
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
          body: FadeTransition(
            opacity: CurvedAnimation(parent: _tabFade, curve: Curves.easeOut),
            child: IndexedStack(index: safeIndex, children: screens),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: _selectTab,
            destinations: navItems,
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: PigLoader())),
      error: (error, stack) {
        debugPrint('Profile load failed: $error');

        final fallbackScreens = [
          const FarmerDashboardScreen(),
          const MapScreen(),
          const BreederListScreen(),
          const FavoritesScreen(),
          const ProfileScreen(),
        ];

        final fallbackNavItems = [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: tr('Home'),
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: tr('Map'),
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: tr('Breeders'),
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: tr('Favorites'),
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: tr('Profile'),
          ),
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
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex < fallbackScreens.length
                ? _currentIndex
                : 0,
            onDestinationSelected: _selectTab,
            destinations: fallbackNavItems,
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

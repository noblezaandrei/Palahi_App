import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../breeder/repositories/stud_pig_repository.dart';
import '../../breeder/repositories/breeding_request_repository.dart';
import '../../breeder/repositories/breeder_repository.dart';
import '../../breeder/repositories/review_repository.dart';
import '../../breeder/views/widgets/review_dialog.dart';
import '../../breeder/models/breeder_model.dart';
import '../../breeder/models/stud_pig_model.dart';
import '../../auth/repositories/auth_repository.dart';
import 'package:palahi/core/constants/colors.dart';
import '../../communication/repositories/notification_repository.dart';
import '../../communication/repositories/chat_repository.dart';
import '../../communication/views/chat_room_screen.dart';
import 'package:palahi/core/widgets/full_screen_image_viewer.dart';
import 'package:palahi/features/map/views/widgets/active_trip_banner.dart';

String getAppGreetingName(
  Map<String, dynamic>? profile, {
  String fallbackName = 'Farmer',
}) {
  final role = (profile?['role'] as String?)?.toLowerCase();
  final profileName = (profile?['name'] as String?)?.trim();

  if (profileName != null && profileName.isNotEmpty) {
    return profileName;
  }

  if (role == 'breeder') {
    return 'Breeder';
  }

  if (role == 'farmer') {
    return 'Farmer';
  }

  return fallbackName;
}

class FarmerDashboardScreen extends ConsumerStatefulWidget {
  const FarmerDashboardScreen({super.key});

  @override
  ConsumerState<FarmerDashboardScreen> createState() =>
      _FarmerDashboardScreenState();
}

class _FarmerDashboardScreenState extends ConsumerState<FarmerDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedBreed = 'All';
  String _selectedService = 'All';
  String _selectedLocation = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    final pigsAsync = ref.watch(allAvailablePigsProvider);
    final breedersAsync = ref.watch(breedersStreamProvider);
    final requestsAsync = ref.watch(farmerRequestsProvider(user.uid));
    final unreadNotifications = ref.watch(
      unreadNotificationCountProvider(user.uid),
    );
    final unreadMessages = ref.watch(
      unreadChatNotificationCountProvider(user.uid),
    );
    final profile = ref.watch(currentUserProfileProvider).value;

    final userName = getAppGreetingName(profile, fallbackName: 'Farmer');
    // Filter options come from the listings themselves so breeds/barangays
    // that breeders actually typed can be selected, not just a fixed few.
    final breedOptions = _mergeOptions(const [
      'Duroc',
      'Landrace',
      'Large White',
    ], (pigsAsync.value ?? const <StudPigModel>[]).map((p) => p.breed));
    const serviceOptions = [
      'All',
      'Natural Breeding',
      'Artificial Insemination',
      'Both',
    ];
    final locationOptions = _mergeOptions(
      const ['Camalig', 'Palanog', 'Mauraro'],
      (breedersAsync.value ?? const <BreederModel>[]).map(
        (b) => b.location.split(',').first,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildDashboardHeader(
              context,
              userName,
              unreadNotifications,
              unreadMessages,
            ),
          ),
          // Live "breeder is on the way" card — right under the header so it
          // can't be missed.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ActiveTripBanner(farmerId: user.uid),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search breeders, breeds, or location',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterButton(
                        breedOptions,
                        serviceOptions,
                        locationOptions,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Trusted Breeders',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildTrustedBreedersSection(breedersAsync, context),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Text(
                'Available Stud Pigs',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
          pigsAsync.when(
            data: (pigs) {
              return breedersAsync.when(
                data: (breeders) {
                  final filteredPigs = pigs.where((pig) {
                    final breeder = breeders.firstWhere(
                      (b) => b.id == pig.breederId,
                      orElse: () => BreederModel(
                        id: '',
                        userId: '',
                        farmName: '',
                        location: '',
                        latitude: 0,
                        longitude: 0,
                        rating: 5,
                        reviewCount: 0,
                        imageUrl: '',
                        about: '',
                        services: [],
                      ),
                    );

                    final searchText = _searchController.text
                        .trim()
                        .toLowerCase();
                    final matchesSearch =
                        searchText.isEmpty ||
                        pig.name.toLowerCase().contains(searchText) ||
                        pig.breed.toLowerCase().contains(searchText) ||
                        pig.description.toLowerCase().contains(searchText) ||
                        breeder.farmName.toLowerCase().contains(searchText) ||
                        breeder.location.toLowerCase().contains(searchText);

                    final pigBreed = pig.breed.trim().toLowerCase();
                    final selectedBreed = _selectedBreed.toLowerCase();
                    final matchesBreed =
                        _selectedBreed == 'All' ||
                        pigBreed == selectedBreed ||
                        pigBreed.contains(selectedBreed);

                    // A pig offering 'Both' satisfies either single service.
                    final pigService = pig.serviceType.trim().toLowerCase();
                    final matchesService =
                        _selectedService == 'All' ||
                        pigService == _selectedService.toLowerCase() ||
                        (_selectedService != 'Both' && pigService == 'both');

                    final matchesLocation =
                        _selectedLocation == 'All' ||
                        breeder.location.toLowerCase().contains(
                          _selectedLocation.toLowerCase(),
                        );

                    return matchesSearch &&
                        matchesBreed &&
                        matchesService &&
                        matchesLocation;
                  }).toList();

                  if (filteredPigs.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: Center(
                          child: Text('No matching available pigs found.'),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 246,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final pig = filteredPigs[index];
                        // An orphaned pig shows "Unknown Farm" rather than
                        // borrowing the first breeder's name and location.
                        final breeder = breeders.firstWhere(
                          (b) => b.id == pig.breederId,
                          orElse: () => BreederModel(
                            id: pig.breederId,
                            userId: pig.breederId,
                            farmName: 'Unknown Farm',
                            location: '',
                            latitude: 0,
                            longitude: 0,
                            rating: 0,
                            reviewCount: 0,
                            imageUrl: '',
                            about: '',
                            services: const [],
                          ),
                        );
                        return _buildPigGridCard(context, pig, breeder);
                      }, childCount: filteredPigs.length),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Center(child: Text('Error loading breeders: $e')),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Center(child: Text('Error loading pigs: $e')),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Text(
                'Booking Requests',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
          requestsAsync.when(
            data: (allRequests) {
              // Completed/rejected/cancelled requests move to History
              // (Profile > Breeding History) instead of cluttering the
              // dashboard.
              final requests = allRequests
                  .where((r) => !terminalBookingStatuses.contains(r.status))
                  .toList();

              if (requests.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 16,
                    ),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('You have no active booking requests.'),
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final r = requests[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: r.studPigImageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: r.studPigImageUrl,
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.cover,
                                          errorWidget: (context, url, error) =>
                                              Container(
                                                color: Colors.grey.shade200,
                                                width: 64,
                                                height: 64,
                                                child: const Icon(
                                                  Icons.broken_image,
                                                  size: 24,
                                                ),
                                              ),
                                        )
                                      : Container(
                                          color: Colors.grey.shade200,
                                          width: 64,
                                          height: 64,
                                          child: const Icon(
                                            Icons.pets,
                                            size: 28,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.studPigName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Breeder: ${r.breederName}'),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Schedule: ${r.bookingDate} at ${r.bookingTime}',
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                      r.status,
                                    ).withAlpha(38),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    r.status == 'done_breeding'
                                        ? 'In Progress'
                                        : r.status
                                              .replaceAll('_', ' ')
                                              .toUpperCase(),
                                    style: TextStyle(
                                      color: _getStatusColor(r.status),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final chatRepo = ref.read(
                                        chatRepositoryProvider,
                                      );
                                      final String roomId;
                                      try {
                                        roomId = await chatRepo
                                            .getOrCreateChatRoom(
                                              farmerId: r.farmerId,
                                              farmerName: r.farmerName,
                                              breederId: r.breederId,
                                              breederName: r.breederName,
                                            );
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Could not open chat: $e',
                                              ),
                                            ),
                                          );
                                        }
                                        return;
                                      }
                                      if (context.mounted) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ChatRoomScreen(
                                                  roomId: roomId,
                                                  otherParticipantName:
                                                      r.breederName.isNotEmpty
                                                      ? r.breederName
                                                      : 'Breeder',
                                                ),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.chat_bubble_outline,
                                      size: 18,
                                    ),
                                    label: const Text('Message Breeder'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (r.status == 'accepted' ||
                                    r.status == 'done_breeding')
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text(
                                              'Confirm Booking Completed',
                                            ),
                                            content: const Text(
                                              'Are you sure the stud booking service is completed? This will confirm the booking and allow you to rate and review the breeder.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text(
                                                  'Confirm & Rate',
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm != true ||
                                            !context.mounted) {
                                          return;
                                        }
                                        // Capture these up front: completing
                                        // moves this booking to History and
                                        // removes this card, unmounting its
                                        // context.
                                        final navigatorContext = Navigator.of(
                                          context,
                                        ).context;
                                        final messenger = ScaffoldMessenger.of(
                                          context,
                                        );
                                        final reviewRepository = ref.read(
                                          reviewRepositoryProvider,
                                        );
                                        // Completing takes several Firestore
                                        // round trips, so run it alongside the
                                        // dialog instead of making the farmer
                                        // wait for it before they can rate.
                                        final completing = ref
                                            .read(
                                              breedingRequestRepositoryProvider,
                                            )
                                            .updateRequestStatus(
                                              r.id,
                                              'completed',
                                            )
                                            .catchError((Object e) {
                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Could not mark booking completed: $e',
                                                  ),
                                                ),
                                              );
                                            });
                                        await showReviewDialog(
                                          context: navigatorContext,
                                          reviewRepository: reviewRepository,
                                          booking: r,
                                        );
                                        await completing;
                                      },
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                        size: 18,
                                      ),
                                      label: const Text('Confirm Booking'),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }, childCount: requests.length),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Center(child: Text('Error loading requests: $e')),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader(
    BuildContext context,
    String userName,
    AsyncValue<int> unreadNotifications,
    AsyncValue<int> unreadMessages,
  ) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, $userName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Find trusted stud pig breeders near you',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _buildHeaderIconWithBadge(
                      context,
                      icon: Icons.chat_bubble_outline,
                      // A stuck loading spinner instead of the real icon is
                      // worse than a briefly-stale count, so default to 0
                      // rather than blocking on the loading/error states.
                      count: unreadMessages.maybeWhen(
                        data: (value) => value,
                        orElse: () => 0,
                      ),
                      onTap: () => context.push('/messages'),
                    ),
                    const SizedBox(width: 8),
                    _buildHeaderIconWithBadge(
                      context,
                      icon: Icons.notifications,
                      iconSize: 26,
                      count: unreadNotifications.maybeWhen(
                        data: (value) => value,
                        orElse: () => 0,
                      ),
                      onTap: () => context.push('/notifications'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(46),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: const [
                  Icon(Icons.pin_drop, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your location is set to nearby trusted stud pig farms.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIconWithBadge(
    BuildContext context, {
    required IconData icon,
    required int count,
    required VoidCallback onTap,
    double iconSize = 24,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(46),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
        ),
        if (count > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTrustedBreedersSection(
    AsyncValue<List<BreederModel>> breedersAsync,
    BuildContext context,
  ) {
    return breedersAsync.when(
      data: (breeders) {
        // "Trusted" = actually rated by farmers, highest rating first (ties
        // broken by review count) — a breeder no one has reviewed yet isn't
        // trusted, just unproven, so they're excluded here rather than
        // padding the list.
        final rated =
            breeders
                .map(
                  (b) => (
                    breeder: b,
                    rating: ref.watch(breederRatingProvider(b.id)),
                  ),
                )
                .where((entry) => entry.rating.count > 0)
                .toList()
              ..sort((a, b) {
                final byRating = b.rating.average.compareTo(a.rating.average);
                if (byRating != 0) return byRating;
                return b.rating.count.compareTo(a.rating.count);
              });

        if (rated.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              'No reviewed breeders yet — check back once farmers start leaving reviews.',
            ),
          );
        }

        final topBreeders = rated.take(4).map((e) => e.breeder).toList();

        return SizedBox(
          height: 210,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: topBreeders.length,
            separatorBuilder: (_, unused) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final breeder = topBreeders[index];
              return _buildBreederCard(context, breeder);
            },
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Center(child: Text('Error loading breeders: $e')),
      ),
    );
  }

  /// 'All' + [defaults] + any extra values from the data, de-duplicated
  /// case-insensitively and skipping blanks / placeholder values.
  List<String> _mergeOptions(List<String> defaults, Iterable<String> values) {
    final options = <String>['All'];
    final seen = <String>{'all'};
    for (final raw in [...defaults, ...values]) {
      final value = raw.trim();
      final key = value.toLowerCase();
      if (value.isEmpty || key.startsWith('unknown') || !seen.add(key)) {
        continue;
      }
      options.add(value);
    }
    return options;
  }

  Widget _buildFilterChips({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            return ChoiceChip(
              label: Text(option),
              selected: selected == option,
              onSelected: (_) => onSelected(option),
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected == option ? Colors.white : AppColors.textDark,
                fontWeight: FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFilterButton(
    List<String> breedOptions,
    List<String> serviceOptions,
    List<String> locationOptions,
  ) {
    final activeCount = [
      _selectedBreed,
      _selectedService,
      _selectedLocation,
    ].where((value) => value != 'All').length;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () =>
                _openFilterSheet(breedOptions, serviceOptions, locationOptions),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Icon(Icons.tune, color: Colors.white),
            ),
          ),
        ),
        if (activeCount > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$activeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openFilterSheet(
    List<String> breedOptions,
    List<String> serviceOptions,
    List<String> locationOptions,
  ) async {
    String tempBreed = _selectedBreed;
    String tempService = _selectedService;
    String tempLocation = _selectedLocation;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            // Scrollable + SafeArea: with many breed/location chips the
            // sheet can be taller than the screen, and on gesture-nav phones
            // the Apply button would sit under the system bar.
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filters',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setSheetState(() {
                            tempBreed = 'All';
                            tempService = 'All';
                            tempLocation = 'All';
                          }),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildFilterChips(
                      title: 'Breed',
                      options: breedOptions,
                      selected: tempBreed,
                      onSelected: (value) =>
                          setSheetState(() => tempBreed = value),
                    ),
                    const SizedBox(height: 16),
                    _buildFilterChips(
                      title: 'Service',
                      options: serviceOptions,
                      selected: tempService,
                      onSelected: (value) =>
                          setSheetState(() => tempService = value),
                    ),
                    const SizedBox(height: 16),
                    _buildFilterChips(
                      title: 'Location',
                      options: locationOptions,
                      selected: tempLocation,
                      onSelected: (value) =>
                          setSheetState(() => tempLocation = value),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedBreed = tempBreed;
                            _selectedService = tempService;
                            _selectedLocation = tempLocation;
                          });
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('Apply Filters'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBreederCard(BuildContext context, BreederModel breeder) {
    final rating = ref.watch(breederRatingProvider(breeder.id));
    return GestureDetector(
      onTap: () => context.push('/breeder/${breeder.id}'),
      child: Container(
        width: 182,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Flexible so the carousel's fixed height never overflows.
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: breeder.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: breeder.imageUrl,
                        height: double.infinity,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, size: 32),
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.pets, size: 32),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    breeder.farmName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    breeder.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textLight, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          rating.count > 0
                              ? '${rating.average.toStringAsFixed(1)} • ${rating.count} reviews'
                              : 'New',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPigGridCard(
    BuildContext context,
    StudPigModel pig,
    BreederModel breeder,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        onTap: () {
          context.push('/breeder/${pig.breederId}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Flexible (not a fixed 110) so the photo gives up space when the
            // text below needs more — e.g. a larger phone font size — instead
            // of the card overflowing its fixed grid cell.
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: pig.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: pig.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            width: double.infinity,
                            height: double.infinity,
                            child: const Icon(
                              Icons.pets,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(153),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        pig.serviceType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (pig.imageUrl.isNotEmpty)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: ViewFullImageButton(imageUrl: pig.imageUrl),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pig.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${pig.breed} • ${pig.ageMonths} mo',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                  if (pig.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      pig.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Farm: ${breeder.farmName}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₱${pig.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          breeder.location.split(',').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'done_breeding':
        return Colors.blue;
      case 'completed':
        return Colors.teal;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }
}

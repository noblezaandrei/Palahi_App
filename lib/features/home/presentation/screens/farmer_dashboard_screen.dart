import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../breeder/data/stud_pig_repository.dart';
import '../../../breeder/data/breeding_request_repository.dart';
import '../../../breeder/data/breeder_repository.dart';
import '../../../breeder/data/review_repository.dart';
import '../../../breeder/domain/models/review_model.dart';
import '../../../breeder/domain/models/breeding_request_model.dart';
import '../../../breeder/domain/models/breeder_model.dart';
import '../../../breeder/domain/models/stud_pig_model.dart';
import '../../../auth/data/auth_repository.dart';
import 'package:palahi/core/constants/colors.dart';
import '../../../communication/data/notification_repository.dart';
import '../../../communication/data/chat_repository.dart';
import '../../../communication/presentation/screens/chat_room_screen.dart';

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
    final profile = ref.watch(currentUserProfileProvider).value;

    final userName = getAppGreetingName(profile, fallbackName: 'Farmer');
    const breedOptions = ['All', 'Duroc', 'Landrace', 'Large White'];
    const serviceOptions = [
      'All',
      'Natural Breeding',
      'Artificial Insemination',
      'Both',
    ];
    const locationOptions = ['All', 'Camalig', 'Palanog', 'Mauraro'];

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildDashboardHeader(
              context,
              userName,
              unreadNotifications,
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
                    final searchText = _searchController.text.toLowerCase();
                    final matchesSearch =
                        searchText.isEmpty ||
                        pig.name.toLowerCase().contains(searchText) ||
                        pig.breed.toLowerCase().contains(searchText);

                    final matchesBreed =
                        _selectedBreed == 'All' ||
                        pig.breed.toLowerCase() == _selectedBreed.toLowerCase();

                    final matchesService =
                        _selectedService == 'All' ||
                        pig.serviceType == _selectedService ||
                        pig.serviceType == 'Both';

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
                            mainAxisExtent: 230,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final pig = filteredPigs[index];
                        final breeder = breeders.firstWhere(
                          (b) => b.id == pig.breederId,
                          orElse: () => breeders.isNotEmpty
                              ? breeders.first
                              : BreederModel(
                                  id: pig.breederId,
                                  userId: pig.breederId,
                                  farmName: 'Unknown Farm',
                                  location: '',
                                  latitude: 14.5995,
                                  longitude: 120.9842,
                                  rating: 5.0,
                                  reviewCount: 0,
                                  imageUrl: '',
                                  about: '',
                                  services: [],
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
                                      final roomId = await chatRepo
                                          .getOrCreateChatRoom(
                                            farmerId: r.farmerId,
                                            farmerName: r.farmerName,
                                            breederId: r.breederId,
                                            breederName: r.breederName,
                                          );
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
                                        if (confirm == true) {
                                          await ref
                                              .read(
                                                breedingRequestRepositoryProvider,
                                              )
                                              .updateRequestStatus(
                                                r.id,
                                                'completed',
                                              );
                                          if (context.mounted) {
                                            _showReviewDialog(context, ref, r);
                                          }
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                        size: 18,
                                      ),
                                      label: const Text('Confirm Booking'),
                                    ),
                                  ),
                                if (r.status == 'completed')
                                  Expanded(
                                    child: FutureBuilder<bool>(
                                      future: ref
                                          .read(reviewRepositoryProvider)
                                          .isBookingReviewed(r.id),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData &&
                                            snapshot.data == false) {
                                          return ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.amber.shade700,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            onPressed: () => _showReviewDialog(
                                              context,
                                              ref,
                                              r,
                                            ),
                                            icon: const Icon(
                                              Icons.star_rate,
                                              size: 18,
                                            ),
                                            label: const Text('Rate Breeder'),
                                          );
                                        }
                                        if (snapshot.hasData &&
                                            snapshot.data == true) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.amber.shade300,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: const [
                                                Icon(
                                                  Icons.star,
                                                  color: Colors.amber,
                                                  size: 16,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Reviewed',
                                                  style: TextStyle(
                                                    color: Colors.amber,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                        return const SizedBox();
                                      },
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Find trusted stud pig breeders near you',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: () => context.push('/messages'),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(46),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    unreadNotifications.when(
                      loading: () => const SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      error: (_, unused) => const SizedBox(width: 40, height: 40),
                      data: (count) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            InkWell(
                              onTap: () => context.push('/notifications'),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(46),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.notifications,
                                  color: Colors.white,
                                  size: 26,
                                ),
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
                      },
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

  Widget _buildTrustedBreedersSection(
    AsyncValue<List<BreederModel>> breedersAsync,
    BuildContext context,
  ) {
    return breedersAsync.when(
      data: (breeders) {
        if (breeders.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text('No breeders available at the moment.'),
          );
        }

        return SizedBox(
          height: 210,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: breeders.length > 4 ? 4 : breeders.length,
            separatorBuilder: (_, unused) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final breeder = breeders[index];
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
            onTap: () => _openFilterSheet(
              breedOptions,
              serviceOptions,
              locationOptions,
            ),
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
            return Padding(
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
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: breeder.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: breeder.imageUrl,
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 110,
                        color: Colors.grey.shade200,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 110,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, size: 32),
                      ),
                    )
                  : Container(
                      height: 110,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.pets, size: 32),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
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
                      Text(
                        rating.count > 0
                            ? '${rating.average.toStringAsFixed(1)} • ${rating.count} reviews'
                            : 'New',
                        style: const TextStyle(fontSize: 12),
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
            SizedBox(
              height: 110,
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
                            height: 110,
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
                            height: 110,
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
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
                      Text(
                        breeder.location.split(',').first,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
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

  void _showReviewDialog(
    BuildContext context,
    WidgetRef ref,
    BreedingRequestModel booking,
  ) {
    double breederRating = 5.0;
    double pigRating = 5.0;
    final breederReviewController = TextEditingController();
    final pigReviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rate Breeder & Stud Pig'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Rate Breeder & Farm:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    return IconButton(
                      icon: Icon(
                        starIndex <= breederRating
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 24,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          breederRating = starIndex.toDouble();
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: breederReviewController,
                  decoration: const InputDecoration(
                    labelText: 'Write a Breeder Review',
                    hintText: 'Share feedback about the breeder...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Text(
                  '2. Rate Stud Pig (${booking.studPigName}):',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    return IconButton(
                      icon: Icon(
                        starIndex <= pigRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 24,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          pigRating = starIndex.toDouble();
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: pigReviewController,
                  decoration: const InputDecoration(
                    labelText: 'Write a Stud Pig Review',
                    hintText: 'Share feedback about the stud pig...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final breederText = breederReviewController.text.trim();
                final pigText = pigReviewController.text.trim();

                if (breederText.isEmpty || pigText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please write reviews for both.'),
                    ),
                  );
                  return;
                }

                try {
                  final review = ReviewModel(
                    id: '',
                    bookingId: booking.id,
                    breederId: booking.breederId,
                    farmerId: booking.farmerId,
                    farmerName: booking.farmerName,
                    rating: breederRating,
                    review: breederText,
                    studPigId: booking.studPigId,
                    studPigName: booking.studPigName,
                    studPigRating: pigRating,
                    studPigReview: pigText,
                    createdAt: DateTime.now(),
                  );

                  await ref.read(reviewRepositoryProvider).addReview(review);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reviews submitted successfully!'),
                      ),
                    );
                    setState(() {});
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error submitting reviews: $e')),
                    );
                  }
                }
              },
              child: const Text('Submit Review'),
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

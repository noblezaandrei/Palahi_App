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
import '../../../../core/constants/colors.dart';

class FarmerDashboardScreen extends ConsumerStatefulWidget {
  const FarmerDashboardScreen({super.key});

  @override
  ConsumerState<FarmerDashboardScreen> createState() => _FarmerDashboardScreenState();
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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header banner
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Find Your Breeding Partner',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Search for certified breeders and superior genetics',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  // Search TextField
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search pig name or breed...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filters Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedBreed = 'All';
                            _selectedService = 'All';
                            _selectedLocation = 'All';
                            _searchController.clear();
                          });
                        },
                        child: const Text('Reset'),
                      )
                    ],
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Breed Filter Dropdown
                        _buildFilterDropdown(
                          label: 'Breed: $_selectedBreed',
                          items: ['All', 'Duroc', 'Landrace', 'Large White', 'Pietrain'],
                          selected: _selectedBreed,
                          onChanged: (val) => setState(() => _selectedBreed = val!),
                        ),
                        const SizedBox(width: 8),
                        // Service Filter Dropdown
                        _buildFilterDropdown(
                          label: 'Service: $_selectedService',
                          items: ['All', 'Natural Breeding', 'Artificial Insemination'],
                          selected: _selectedService,
                          onChanged: (val) => setState(() => _selectedService = val!),
                        ),
                        const SizedBox(width: 8),
                        // Location Filter Dropdown
                        _buildFilterDropdown(
                          label: 'Location: $_selectedLocation',
                          items: ['All', 'Bulacan', 'Manila', 'Pampanga'],
                          selected: _selectedLocation,
                          onChanged: (val) => setState(() => _selectedLocation = val!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Available Pigs Grid
          pigsAsync.when(
            data: (pigs) {
              return breedersAsync.when(
                data: (breeders) {
                  // Filter the pigs list client-side
                  final filteredPigs = pigs.where((pig) {
                    final matchesSearch = pig.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                        pig.breed.toLowerCase().contains(_searchController.text.toLowerCase());
                    
                    final matchesBreed = _selectedBreed == 'All' || pig.breed.toLowerCase() == _selectedBreed.toLowerCase();
                    
                    final matchesService = _selectedService == 'All' ||
                        pig.serviceType == _selectedService ||
                        pig.serviceType == 'Both';

                    // Get breeder location to filter by location
                    final breeder = breeders.firstWhere((b) => b.id == pig.breederId,
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
                            ));
                    
                    final matchesLocation = _selectedLocation == 'All' ||
                        breeder.location.toLowerCase().contains(_selectedLocation.toLowerCase());

                    return matchesSearch && matchesBreed && matchesService && matchesLocation;
                  }).toList();

                  if (filteredPigs.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: Center(child: Text('No matching available pigs found.')),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.76,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
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
                        },
                        childCount: filteredPigs.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
                error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error loading breeders: $e'))),
              );
            },
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error loading pigs: $e'))),
          ),

          // Booking Status Tracker Header
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Text(
                'My Booking Requests',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),

          // Requests list
          requestsAsync.when(
            data: (requests) {
              if (requests.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('You have no active requests or booking history.'),
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final r = requests[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: r.studPigImageUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: r.studPigImageUrl,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) => Container(
                                      color: Colors.grey.shade200,
                                      width: 50,
                                      height: 50,
                                      child: const Icon(Icons.broken_image, size: 24),
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey.shade200,
                                    width: 50,
                                    height: 50,
                                    child: const Icon(Icons.pets, size: 24),
                                  ),
                          ),
                          title: Text(
                            r.studPigName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Breeder: ${r.breederName}'),
                              Text('Type: ${r.breedingType}'),
                              Text('Schedule: ${r.bookingDate} at ${r.bookingTime}'),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(r.status).withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  r.status.toUpperCase(),
                                  style: TextStyle(
                                    color: _getStatusColor(r.status),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              if (r.status == 'completed') ...[
                                const SizedBox(height: 4),
                                FutureBuilder<bool>(
                                  future: ref.read(reviewRepositoryProvider).isBookingReviewed(r.id),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData && snapshot.data == false) {
                                      return TextButton(
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(60, 24),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () => _showReviewDialog(context, ref, r),
                                        child: const Text('Review', style: TextStyle(fontSize: 11)),
                                      );
                                    }
                                    if (snapshot.hasData && snapshot.data == true) {
                                      return const Text(
                                        'Reviewed',
                                        style: TextStyle(fontSize: 11, color: Colors.grey),
                                      );
                                    }
                                    return const SizedBox();
                                  },
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: requests.length,
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error loading requests: $e'))),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required List<String> items,
    required String selected,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButton<String>(
        value: selected,
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down),
        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPigGridCard(BuildContext context, StudPigModel pig, BreederModel breeder) {
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
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: pig.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: pig.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.shade200,
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            width: double.infinity,
                            child: const Icon(Icons.pets, size: 40, color: Colors.grey),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(150),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        pig.serviceType,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pig.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pig.breed} • ${pig.ageMonths} mo',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                  Text(
                    'Farm: ${breeder.farmName}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
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
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
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

  void _showReviewDialog(BuildContext context, WidgetRef ref, BreedingRequestModel booking) {
    double selectedRating = 5.0;
    final reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Rate Breeder for ${booking.studPigName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How was your breeding experience?'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return IconButton(
                    icon: Icon(
                      starIndex <= selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        selectedRating = starIndex.toDouble();
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reviewController,
                decoration: const InputDecoration(
                  labelText: 'Write a Review',
                  hintText: 'Share your feedback about the breeder...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final reviewText = reviewController.text.trim();
                if (reviewText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please write a review')),
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
                    rating: selectedRating,
                    review: reviewText,
                    createdAt: DateTime.now(),
                  );

                  await ref.read(reviewRepositoryProvider).addReview(review);
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Review submitted successfully!')),
                    );
                    setState(() {}); // Rebuild to update "Review" button to "Reviewed"
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error submitting review: $e')),
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

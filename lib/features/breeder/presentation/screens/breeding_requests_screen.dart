import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/breeding_request_repository.dart';
import '../../data/review_repository.dart';
import '../../data/trip_repository.dart';
import '../../domain/models/breeding_request_model.dart';
import '../widgets/review_dialog.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../communication/data/chat_repository.dart';
import '../../../communication/presentation/screens/chat_room_screen.dart';
import '../../../map/data/farmer_location_repository.dart';
import '../../../map/data/location_service.dart';
import '../../../map/presentation/screens/live_tracking_screen.dart';
import '../../../../core/constants/colors.dart';
import 'breeder_history_screen.dart';

class BreedingRequestsScreen extends ConsumerWidget {
  // true when embedded as a breeder tab (home_screen.dart already shows an
  // app bar with back-independent nav icons there); false when pushed as a
  // standalone route, where this screen needs its own app bar/back button.
  final bool embeddedInTabs;

  const BreedingRequestsScreen({super.key, this.embeddedInTabs = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final profileAsync = ref.watch(currentUserProfileProvider);
    final userRole = profileAsync.value?['role'] ?? 'farmer';
    final isFarmer = userRole == 'farmer';
    final greetingName =
        (profileAsync.value?['name'] as String?)?.trim().isNotEmpty == true
        ? profileAsync.value!['name'] as String
        : (isFarmer ? 'Farmer' : 'Breeder');

    final requestsAsyncValue = isFarmer
        ? ref.watch(farmerRequestsProvider(user.uid))
        : ref.watch(breederRequestsProvider(user.uid));

    final title = isFarmer
        ? 'My Breeding Requests'
        : 'Incoming Breeding Requests';

    return Scaffold(
      appBar: embeddedInTabs
          ? null
          : AppBar(
              title: Text(title),
              actions: [
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: 'History',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BreedingHistoryScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $greetingName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: requestsAsyncValue.when(
              data: (allRequests) {
                // Completed/rejected/cancelled requests move to History
                // instead of cluttering the active list.
                final requests = allRequests
                    .where((r) => !terminalBookingStatuses.contains(r.status))
                    .toList();

                if (requests.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isFarmer
                                ? 'You have no active breeding requests.'
                                : 'No incoming breeding requests.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isFarmer
                                ? 'Browse stud pigs and send booking requests to breeders.'
                                : 'When farmers request breeding services, they will appear here.',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Pig: ${request.studPigName}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                _buildStatusChip(request.status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (request.studPigImageUrl.isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  request.studPigImageUrl,
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: _buildParticipantTile(
                                    label: 'Farmer',
                                    name: request.farmerName,
                                    imageUrl: request.farmerImageUrl,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildParticipantTile(
                                    label: 'Breeder',
                                    name: request.breederName,
                                    imageUrl: request.breederImageUrl,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Breeding Type: ${request.breedingType}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Schedule: ${request.bookingDate} at ${request.bookingTime}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Booked on: ${request.createdAt.month}/${request.createdAt.day}/${request.createdAt.year}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (request.notes.isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Notes: "${request.notes}"',
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            // Messaging & Action Buttons Row
                            Row(
                              children: [
                                // Message button accessible to both farmer and breeder
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final chatRepo = ref.read(
                                        chatRepositoryProvider,
                                      );
                                      final roomId = await chatRepo
                                          .getOrCreateChatRoom(
                                            farmerId: request.farmerId,
                                            farmerName: request.farmerName,
                                            breederId: request.breederId,
                                            breederName: request.breederName,
                                          );
                                      if (context.mounted) {
                                        final otherName = isFarmer
                                            ? request.breederName
                                            : request.farmerName;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ChatRoomScreen(
                                                  roomId: roomId,
                                                  otherParticipantName:
                                                      otherName.isNotEmpty
                                                      ? otherName
                                                      : (isFarmer
                                                            ? 'Breeder'
                                                            : 'Farmer'),
                                                ),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.chat_bubble_outline,
                                      size: 18,
                                    ),
                                    label: const Text('Message'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (request.status == 'pending') ...[
                                  if (!isFarmer) ...[
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          ref
                                              .read(
                                                breedingRequestRepositoryProvider,
                                              )
                                              .updateRequestStatus(
                                                request.id,
                                                'rejected',
                                              );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.error,
                                        ),
                                        child: const Text('Reject'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          ref
                                              .read(
                                                breedingRequestRepositoryProvider,
                                              )
                                              .updateRequestStatus(
                                                request.id,
                                                'accepted',
                                              );
                                        },
                                        child: const Text('Accept'),
                                      ),
                                    ),
                                  ] else ...[
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          ref
                                              .read(
                                                breedingRequestRepositoryProvider,
                                              )
                                              .updateRequestStatus(
                                                request.id,
                                                'cancelled',
                                              );
                                        },
                                        icon: const Icon(Icons.cancel_outlined),
                                        label: const Text('Cancel'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ] else if (request.status == 'accepted' ||
                                    request.status == 'done_breeding') ...[
                                  if (isFarmer) ...[
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text(
                                                'Confirm Booking Completed',
                                              ),
                                              content: const Text(
                                                'Are you sure the stud booking service is completed? This will confirm the booking and allow you to review the breeder.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: const Text(
                                                    'Confirm & Rate Breeder',
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
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          final reviewRepository = ref.read(
                                            reviewRepositoryProvider,
                                          );
                                          // Completing takes several Firestore
                                          // round trips, so run it alongside
                                          // the dialog instead of making the
                                          // farmer wait for it before rating.
                                          final completing = ref
                                              .read(
                                                breedingRequestRepositoryProvider,
                                              )
                                              .updateRequestStatus(
                                                request.id,
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
                                            booking: request,
                                          );
                                          await completing;
                                        },
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                          size: 18,
                                        ),
                                        label: const Text('Confirm Booking'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    if (request.status == 'done_breeding')
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                  'Confirm Cash Received',
                                                ),
                                                content: const Text(
                                                  'Confirm that you have received the CASH payment from the farmer.',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          false,
                                                        ),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          true,
                                                        ),
                                                    child: const Text(
                                                      'Confirm Cash Received',
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
                                                    request.id,
                                                    'completed',
                                                  );
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.payments_outlined,
                                            size: 18,
                                          ),
                                          label: const Text('Receive Payment'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.teal,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      )
                                    else
                                      const Expanded(
                                        child: Center(
                                          child: Text(
                                            'Awaiting farmer completion...',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                ],
                              ],
                            ),
                            if (request.status == 'accepted')
                              _buildTripSection(
                                context,
                                ref,
                                request,
                                isFarmer,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantTile({
    required String label,
    required String name,
    required String imageUrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: imageUrl.isNotEmpty
                ? NetworkImage(imageUrl)
                : null,
            child: imageUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.black54),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name.isNotEmpty ? name : 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'accepted':
        color = Colors.green;
        break;
      case 'done_breeding':
        color = Colors.blue;
        break;
      case 'completed':
        color = Colors.teal;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      case 'cancelled':
        color = Colors.grey;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status == 'done_breeding' ? 'DONE BREEDING' : status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// For an accepted booking: farmers get a "track breeder" button once the
  /// breeder starts a trip; breeders get directions to the farm plus
  /// Start Trip / Arrived controls.
  Widget _buildTripSection(
    BuildContext context,
    WidgetRef ref,
    BreedingRequestModel request,
    bool isFarmer,
  ) {
    final tripAsync = ref.watch(tripLocationStreamProvider(request.id));
    final isActive = tripAsync.maybeWhen(
      data: (trip) => trip?.active ?? false,
      orElse: () => false,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: isFarmer
          ? SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isActive
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LiveTrackingScreen(
                              bookingId: request.id,
                              breederName: request.breederName,
                            ),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.pin_drop_outlined),
                label: Text(
                  isActive
                      ? "Track Breeder's Location"
                      : "Breeder hasn't started the trip yet",
                ),
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _openDirectionsToFarmer(context, ref, request),
                    icon: const Icon(Icons.directions),
                    label: const Text('Directions'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: isActive
                      ? OutlinedButton.icon(
                          onPressed: () => ref
                              .read(tripTrackingControllerProvider)
                              .stopTrip(),
                          icon: const Icon(Icons.flag_outlined),
                          label: const Text('Arrived'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal,
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: () => ref
                              .read(tripTrackingControllerProvider)
                              .startTrip(
                                bookingId: request.id,
                                breederId: request.breederId,
                                farmerId: request.farmerId,
                              ),
                          icon: const Icon(Icons.navigation_outlined),
                          label: const Text('Start Trip'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _openDirectionsToFarmer(
    BuildContext context,
    WidgetRef ref,
    BreedingRequestModel request,
  ) async {
    final farmLocation = await ref
        .read(farmerLocationRepositoryProvider)
        .getLocation(request.farmerId);

    if (farmLocation == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("This farmer hasn't pinned their farm location yet."),
          ),
        );
      }
      return;
    }

    String? origin;
    try {
      final position = await ref
          .read(locationServiceProvider)
          .getCurrentLocation();
      origin = '${position.latitude},${position.longitude}';
    } catch (_) {
      origin = null;
    }

    final url = Uri.parse(
      origin != null
          ? 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=${farmLocation.latitude},${farmLocation.longitude}'
          : 'https://www.google.com/maps/search/?api=1&query=${farmLocation.latitude},${farmLocation.longitude}',
    );

    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open directions.')),
      );
    }
  }
}

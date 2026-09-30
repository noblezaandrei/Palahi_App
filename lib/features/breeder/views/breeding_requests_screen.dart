import 'package:palahi/core/widgets/button_label.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palahi/core/widgets/pig_icon.dart';
import 'package:palahi/core/widgets/user_avatar.dart';
import 'package:palahi/core/widgets/gradient_header.dart';
import 'package:palahi/features/home/views/farmer_dashboard_screen.dart'
    show BookingProgress, bookingStatusLabel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/breeding_request_repository.dart';
import '../repositories/review_repository.dart';
import '../repositories/trip_repository.dart';
import '../models/breeding_request_model.dart';
import 'widgets/review_dialog.dart';
import 'widgets/booking_sheet.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../communication/repositories/chat_repository.dart';
import '../../communication/views/chat_room_screen.dart';
import '../../map/views/live_tracking_screen.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_utils.dart';
import 'breeder_history_screen.dart';
import 'package:palahi/core/utils/error_messages.dart';
import 'package:palahi/core/widgets/pig_loader.dart';

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
          GradientHeader(
            title: 'Hello, $greetingName',
            subtitle: isFarmer
                ? 'Track each booking from request to completion'
                : 'Accept, track and complete farmers\' bookings',
            stats: switch (requestsAsyncValue.value) {
              final all? => [
                (
                  value: '${all.where((r) => r.status == 'pending').length}',
                  label: 'Waiting',
                ),
                (
                  value: '${all.where((r) => r.status == 'accepted').length}',
                  label: 'Accepted',
                ),
                (
                  value:
                      '${all.where((r) => r.status == 'done_breeding').length}',
                  label: 'Breeding',
                ),
              ],
              _ => const [],
            },
          ),
          Expanded(
            child: requestsAsyncValue.when(
              data: (allRequests) {
                // Completed/rejected/cancelled requests move to History
                // instead of cluttering the active list.
                final requests = allRequests
                    .where((r) => !terminalBookingStatuses.contains(r.status))
                    .toList();

                // A trip still running for a booking that's no longer
                // accepted (completed/cancelled meanwhile) would keep the
                // breeder's GPS streaming forever — end it.
                if (!isFarmer) {
                  final tracker = ref.read(tripTrackingControllerProvider);
                  final tracked = tracker.activeBookingId;
                  if (tracked != null &&
                      !requests.any(
                        (r) => r.id == tracked && r.status == 'accepted',
                      )) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => tracker.stopTrip(),
                    );
                  }
                }

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
                    return FadeSlideIn(
                      index: index,
                      child: Card(
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      request.studPigName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
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
                                  child: SizedBox(
                                    height: 140,
                                    width: double.infinity,
                                    child: CachedNetworkImage(
                                      imageUrl: request.studPigImageUrl,
                                      fit: BoxFit.cover,
                                      // e.g. the pig's photo was deleted.
                                      errorWidget: (_, _, _) =>
                                          const PigPlaceholder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              // Only the other person — your own name isn't
                              // news to you.
                              isFarmer
                                  ? _buildParticipantTile(
                                      label: 'Breeder',
                                      name: request.breederName,
                                      imageUrl: request.breederImageUrl,
                                    )
                                  : _buildParticipantTile(
                                      label: 'Farmer',
                                      name: request.farmerName,
                                      imageUrl: request.farmerImageUrl,
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
                                'Schedule: ${formatBookingSchedule(request.bookingDate, request.bookingTime)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                // When the farmer sent the request, as opposed
                                // to the Schedule above (when the breeding is).
                                'Requested on: ${formatDateTime(request.createdAt)}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              if (request.status == 'pending' &&
                                  bookingTimeHasPassed(
                                    request.bookingDate,
                                    request.bookingTime,
                                  )) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isFarmer
                                        ? 'The scheduled time passed before '
                                              'the breeder answered. You can '
                                              'cancel this and book a new time.'
                                        : 'The scheduled time has passed, so '
                                              'this request can no longer be '
                                              'accepted.',
                                    style: TextStyle(
                                      color: Colors.orange.shade900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
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
                              const SizedBox(height: 12),
                              BookingProgress(status: request.status),
                              if (isFarmer &&
                                  (request.status == 'pending' ||
                                      request.status == 'accepted'))
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => showRescheduleSheet(
                                      context,
                                      ref,
                                      request,
                                    ),
                                    icon: const Icon(
                                      Icons.event_repeat,
                                      size: 18,
                                    ),
                                    label: const Text('Reschedule'),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
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
                                        final String roomId;
                                        try {
                                          roomId = await chatRepo
                                              .getOrCreateChatRoom(
                                                farmerId: request.farmerId,
                                                farmerName: request.farmerName,
                                                breederId: request.breederId,
                                                breederName:
                                                    request.breederName,
                                                farmerImageUrl:
                                                    request.farmerImageUrl,
                                                breederImageUrl:
                                                    request.breederImageUrl,
                                              );
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Could not open chat: ${friendlyError(e)}',
                                                ),
                                              ),
                                            );
                                          }
                                          return;
                                        }
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
                                                    otherParticipantImageUrl:
                                                        isFarmer
                                                        ? request
                                                              .breederImageUrl
                                                        : request
                                                              .farmerImageUrl,
                                                  ),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.chat_bubble_outline,
                                        size: 18,
                                      ),
                                      label: const ButtonLabel('Message'),
                                      style: OutlinedButton.styleFrom(
                                        padding: compactButtonPadding,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (request.status == 'pending') ...[
                                    if (!isFarmer) ...[
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _confirmAndSetStatus(
                                            context,
                                            ref,
                                            request,
                                            'rejected',
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.error,
                                            padding: compactButtonPadding,
                                          ),
                                          child: const ButtonLabel('Reject'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed:
                                              bookingTimeHasPassed(
                                                request.bookingDate,
                                                request.bookingTime,
                                              )
                                              ? null
                                              : () => _setStatus(
                                                  context,
                                                  ref,
                                                  request.id,
                                                  'accepted',
                                                ),
                                          style: ElevatedButton.styleFrom(
                                            padding: compactButtonPadding,
                                          ),
                                          child: const ButtonLabel('Accept'),
                                        ),
                                      ),
                                    ] else ...[
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _confirmAndSetStatus(
                                            context,
                                            ref,
                                            request,
                                            'cancelled',
                                          ),
                                          icon: const Icon(
                                            Icons.cancel_outlined,
                                          ),
                                          label: const ButtonLabel('Cancel'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.error,
                                            padding: compactButtonPadding,
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
                                            final navigatorContext =
                                                Navigator.of(context).context;
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
                                                .withNetworkTimeout()
                                                .catchError((Object e) {
                                                  messenger.showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Could not mark booking completed: ${friendlyError(e)}',
                                                      ),
                                                    ),
                                                  );
                                                });
                                            await showReviewDialog(
                                              context: navigatorContext,
                                              reviewRepository:
                                                  reviewRepository,
                                              booking: request,
                                              completing: completing,
                                            );
                                            await completing;
                                          },
                                          icon: const Icon(
                                            Icons.check_circle_outline,
                                            size: 18,
                                          ),
                                          label: const ButtonLabel(
                                            'Confirm Booking',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.teal,
                                            foregroundColor: Colors.white,
                                            padding: compactButtonPadding,
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
                                                      child: const Text(
                                                        'Cancel',
                                                      ),
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
                                              if (confirm == true &&
                                                  context.mounted) {
                                                await _setStatus(
                                                  context,
                                                  ref,
                                                  request.id,
                                                  'completed',
                                                );
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.payments_outlined,
                                              size: 18,
                                            ),
                                            label: const ButtonLabel(
                                              'Receive Payment',
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.teal,
                                              foregroundColor: Colors.white,
                                              padding: compactButtonPadding,
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
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: PigLoader()),
              error: (error, stack) =>
                  Center(child: Text(friendlyError(error))),
            ),
          ),
        ],
      ),
    );
  }

  /// Asks before rejecting or cancelling, since neither can be undone.
  Future<void> _confirmAndSetStatus(
    BuildContext context,
    WidgetRef ref,
    BreedingRequestModel request,
    String status,
  ) async {
    final rejecting = status == 'rejected';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          rejecting ? 'Reject this request?' : 'Cancel this booking?',
        ),
        content: Text(
          '${request.studPigName} on '
          '${formatBookingSchedule(request.bookingDate, request.bookingTime)}. '
          "This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              rejecting ? 'Reject' : 'Cancel Booking',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await _setStatus(context, ref, request.id, status);
    }
  }

  /// Updates a booking's status, telling the user if it fails instead of
  /// silently leaving the card unchanged.
  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    String requestId,
    String status,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(breedingRequestRepositoryProvider)
          .updateRequestStatus(requestId, status)
          .withNetworkTimeout();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not update the booking: ${friendlyError(e)}'),
        ),
      );
    }
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
          UserAvatar(
            name: name,
            imageUrl: imageUrl,
            backgroundColor: Colors.grey.shade300,
            initialColor: Colors.black54,
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
        bookingStatusLabel(status),
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
    final trip = tripAsync.value;
    final isActive = trip?.active ?? false;

    // Breeder tapped "Arrived": the farmer gets the arrival notice here
    // (it used to be a banner on the home dashboard).
    if (isFarmer && trip != null && !trip.active && trip.arrived) {
      final time = TimeOfDay.fromDateTime(trip.arrivedAt!).format(context);
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Colors.green.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Colors.green, width: 1.5),
          ),
          child: ListTile(
            leading: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 32,
            ),
            title: Text(
              '${request.breederName} has arrived',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Arrived at your farm at $time'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LiveTrackingScreen(
                  bookingId: request.id,
                  breederName: request.breederName,
                  breederImageUrl: request.breederImageUrl,
                  farmerId: request.farmerId,
                  farmerName: request.farmerName,
                  farmerImageUrl: request.farmerImageUrl,
                ),
              ),
            ),
          ),
        ),
      );
    }

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
                              breederImageUrl: request.breederImageUrl,
                              farmerId: request.farmerId,
                              farmerName: request.farmerName,
                              farmerImageUrl: request.farmerImageUrl,
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
          : SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LiveTrackingScreen(
                      bookingId: request.id,
                      breederName: request.breederName,
                      breederImageUrl: request.breederImageUrl,
                      farmerId: request.farmerId,
                      farmerName: request.farmerName,
                      farmerImageUrl: request.farmerImageUrl,
                      breederId: request.breederId,
                    ),
                  ),
                ),
                icon: Icon(isActive ? Icons.navigation : Icons.route_outlined),
                label: Text(
                  isActive
                      ? 'Trip in progress — View Route'
                      : 'View Route & Start Trip',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              ),
            ),
    );
  }
}

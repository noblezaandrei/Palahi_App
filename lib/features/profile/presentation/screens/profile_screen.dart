import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palahi/core/constants/colors.dart';
import 'package:palahi/features/auth/presentation/providers/auth_controller.dart';
import 'package:palahi/features/auth/data/auth_repository.dart';
import 'package:palahi/features/breeder/data/breeder_repository.dart';
import 'package:palahi/features/breeder/domain/models/breeder_model.dart';
import 'edit_profile_screen.dart';
import 'package:palahi/features/breeder/presentation/screens/breeder_history_screen.dart';
import 'about_screen.dart';
import 'settings_screen.dart';
import 'edit_farmer_profile_screen.dart';
import 'package:palahi/features/breeder/data/breeding_request_repository.dart';
import 'package:palahi/features/breeder/data/stud_pig_repository.dart';
import 'package:palahi/features/breeder/data/review_repository.dart';
import 'package:palahi/features/breeder/presentation/screens/manage_availability_screen.dart';
import 'package:palahi/features/communication/data/notification_repository.dart';
import 'package:palahi/core/widgets/badge_icon_button.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final profileAsync = ref.watch(currentUserProfileProvider);
    final breedersAsync = ref.watch(breedersStreamProvider);

    final userName =
        profileAsync.value?['name'] as String? ??
        user?.displayName ??
        'Loading...';
    final userEmail = user?.email ?? '';
    final role = profileAsync.value?['role'] ?? 'farmer';

    String? profileImageUrl = profileAsync.value?['imageUrl'] as String?;
    if ((profileImageUrl == null || profileImageUrl.isEmpty) &&
        user?.photoURL != null) {
      profileImageUrl = user!.photoURL;
    }

    if (role == 'breeder' && user != null) {
      breedersAsync.whenData((breeders) {
        final b = breeders.firstWhere(
          (element) => element.id == user.uid,
          orElse: () => breeders.isNotEmpty
              ? breeders.first
              : BreederModel(
                  id: user.uid,
                  userId: user.uid,
                  farmName: 'My Farm',
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
        profileImageUrl = b.imageUrl.isNotEmpty ? b.imageUrl : profileImageUrl;
      });
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Header Area
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (role == 'breeder')
                            IconButton(
                              icon: const Icon(
                                Icons.event_available,
                                color: Colors.white,
                              ),
                              tooltip: 'Manage Availability',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ManageAvailabilityScreen(),
                                  ),
                                );
                              },
                            ),
                          BadgeIconButton(
                            icon: Icons.chat_bubble_outline,
                            iconColor: Colors.white,
                            count: user == null
                                ? 0
                                : ref
                                          .watch(
                                            unreadChatNotificationCountProvider(
                                              user.uid,
                                            ),
                                          )
                                          .value ??
                                      0,
                            onPressed: () => context.push('/messages'),
                          ),
                          BadgeIconButton(
                            icon: Icons.notifications_outlined,
                            iconColor: Colors.white,
                            count: user == null
                                ? 0
                                : ref
                                          .watch(
                                            unreadNotificationCountProvider(
                                              user.uid,
                                            ),
                                          )
                                          .value ??
                                      0,
                            onPressed: () => context.push('/notifications'),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            backgroundImage:
                                (profileImageUrl != null &&
                                    profileImageUrl!.isNotEmpty)
                                ? NetworkImage(profileImageUrl!)
                                : null,
                            child:
                                (profileImageUrl == null ||
                                    profileImageUrl!.isEmpty)
                                ? const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.grey,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.star,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        userName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userEmail,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(50),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          role.toString().toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () {
                          if (role == 'breeder') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EditProfileScreen(),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EditFarmerProfileScreen(),
                              ),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          minimumSize: const Size(120, 40),
                        ),
                        child: Text(
                          role == 'breeder'
                              ? 'Edit Farm Profile'
                              : 'Edit Profile',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (user != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: role == 'breeder'
                    ? _buildBreederStats(ref, user.uid)
                    : _buildFarmerStats(ref, user.uid),
              ),
            _buildMenuItem(
              context,
              icon: Icons.assignment_outlined,
              title: role == 'breeder'
                  ? 'Manage Incoming Requests'
                  : 'My Breeding Requests',
              onTap: () => context.push('/breeding-requests'),
            ),
            _buildMenuItem(
              context,
              icon: Icons.star_border,
              title: 'My Reviews',
              onTap: () {
                if (user != null) {
                  context.push('/reviews/${user.uid}');
                }
              },
            ),
            _buildMenuItem(
              context,
              icon: Icons.message_outlined,
              title: 'My Messages',
              onTap: () => context.push('/messages'),
            ),

            // Farmer specific or Breeder specific menu items
            if (role == 'breeder') ...[
              _buildMenuItem(
                context,
                icon: Icons.pets_outlined,
                title: 'Manage Stud Pigs',
                onTap: () => context.push('/manage-pig'),
              ),
              _buildMenuItem(
                context,
                icon: Icons.history,
                title: 'Breeding Appointment History',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BreedingHistoryScreen(),
                    ),
                  );
                },
              ),
            ] else ...[
              _buildMenuItem(
                context,
                icon: Icons.assignment_outlined,
                title: 'My Breeding Requests',
                onTap: () {
                  context.push('/breeding-requests');
                },
              ),
              _buildMenuItem(
                context,
                icon: Icons.history,
                title: 'Breeding History',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BreedingHistoryScreen(),
                    ),
                  );
                },
              ),
            ],

            _buildMenuItem(
              context,
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            _buildMenuItem(
              context,
              icon: Icons.info_outline,
              title: 'About PALAHI',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, indent: 20, endIndent: 20),
            const SizedBox(height: 16),
            _buildMenuItem(
              context,
              icon: Icons.logout,
              title: 'Logout',
              isDestructive: true,
              onTap: () async {
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      title: const Row(
                        children: [
                          Icon(Icons.logout, color: Colors.red),
                          SizedBox(width: 10),
                          Text("Logout"),
                        ],
                      ),
                      content: const Text(
                        "Are you sure you want to logout from PALAHI?",
                      ),
                      actions: [
                        TextButton(
                          child: const Text("Cancel"),
                          onPressed: () {
                            Navigator.pop(context, false);
                          },
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Logout"),
                          onPressed: () {
                            Navigator.pop(context, true);
                          },
                        ),
                      ],
                    );
                  },
                );

                if (shouldLogout == true) {
                  await ref.read(authControllerProvider.notifier).logout();

                  if (context.mounted) {
                    context.go('/login');
                  }
                }
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppColors.error : AppColors.textDark;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: color,
          fontWeight: isDestructive ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildFarmerStats(WidgetRef ref, String uid) {
    final all = ref.watch(farmerRequestsProvider(uid));

    final completed = ref.watch(farmerCompletedRequestsProvider(uid));

    final pending = ref.watch(farmerPendingRequestsProvider(uid));

    return Row(
      children: [
        Expanded(
          child: _statCard(
            "Bookings",
            all.value?.length ?? 0,
            Icons.calendar_today,
            Colors.blue,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _statCard(
            "Completed",
            completed.value?.length ?? 0,
            Icons.check_circle,
            Colors.green,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _statCard(
            "Pending",
            pending.value?.length ?? 0,
            Icons.schedule,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildBreederStats(WidgetRef ref, String uid) {
    final pigs = ref.watch(breederStudPigsProvider(uid));

    final completed = ref.watch(completedRequestsForBreederProvider(uid));

    final rating = ref.watch(breederRatingProvider(uid));

    return Row(
      children: [
        Expanded(
          child: _statCard(
            "Stud Pigs",
            pigs.value?.length ?? 0,
            Icons.pets,
            Colors.deepPurple,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _statCard(
            "Completed",
            completed.value?.length ?? 0,
            Icons.task_alt,
            Colors.green,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _statCard(
            "Rating",
            rating.count > 0 ? rating.average.toStringAsFixed(1) : "New",
            Icons.star,
            Colors.amber,
          ),
        ),
      ],
    );
  }

  Widget _statCard(String title, dynamic value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Icon(icon, color: color),

            const SizedBox(height: 8),

            Text(
              "$value",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),

            const SizedBox(height: 4),

            Text(title, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

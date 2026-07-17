import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../breeder/data/breeder_repository.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final profileAsync = ref.watch(currentUserProfileProvider);
    final breedersAsync = ref.watch(breedersStreamProvider);

    final userName = profileAsync.value?['name'] as String? ?? user?.displayName ?? 'Loading...';
    final userEmail = user?.email ?? '';
    final role = profileAsync.value?['role'] ?? 'farmer';

    // Fetch breeder profile image if role is breeder
    String? profileImageUrl;
    if (role == 'breeder' && user != null) {
      breedersAsync.whenData((breeders) {
        final b = breeders.firstWhere((element) => element.id == user.uid, orElse: () => breeders.first);
        profileImageUrl = b.imageUrl;
      });
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Header Area
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 60, bottom: 30),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        backgroundImage: (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                            ? NetworkImage(profileImageUrl!)
                            : null,
                        child: (profileImageUrl == null || profileImageUrl!.isEmpty)
                            ? const Icon(Icons.person, size: 60, color: Colors.grey)
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
                          child: const Icon(Icons.star, size: 20, color: AppColors.primary),
                        ),
                      )
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(50),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      role.toString().toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      if (role == 'breeder') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                        );
                      } else {
                        // Farmer edit name details modal (optional / info pop)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Farmer details are managed via account settings.')),
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
                    child: Text(role == 'breeder' ? 'Edit Farm Profile' : 'Edit Profile'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Menu Items
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
                icon: Icons.assignment_outlined,
                title: 'Manage Incoming Requests',
                onTap: () => context.push('/breeding-requests'),
              ),
              _buildMenuItem(
                context,
                icon: Icons.pets_outlined,
                title: 'Manage Stud Pigs',
                onTap: () => context.push('/manage-pig'),
              ),
            ] else ...[
              _buildMenuItem(
                context,
                icon: Icons.history,
                title: 'My Breeding Requests',
                onTap: () {
                  // Direct to main feed where requests are displayed, or open breeding-requests view.
                  // Breeding requests screen can show breeder incoming, but let's allow farmers to see it too!
                  context.push('/breeding-requests');
                },
              ),
            ],
            
            _buildMenuItem(
              context,
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () {},
            ),
            _buildMenuItem(
              context,
              icon: Icons.info_outline,
              title: 'About PALAHI',
              onTap: () {},
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
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) {
                  context.go('/login');
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
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../auth/data/auth_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final profileAsync = ref.watch(currentUserProfileProvider);
    final userName = profileAsync.value?['name'] as String? ?? user?.displayName ?? 'Loading...';
    final userEmail = user?.email ?? '';

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
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 60, color: Colors.grey),
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
                          child: const Icon(Icons.edit, size: 20, color: AppColors.primary),
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
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      minimumSize: const Size(120, 40),
                    ),
                    child: const Text('Edit Profile'),
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
              onTap: () {},
            ),
            _buildMenuItem(
              context,
              icon: Icons.message_outlined,
              title: 'My Messages',
              onTap: () => context.push('/messages'),
            ),
            _buildMenuItem(
              context,
              icon: Icons.assignment_outlined,
              title: 'Breeding Requests',
              onTap: () => context.push('/breeding-requests'),
            ),
            _buildMenuItem(
              context,
              icon: Icons.pets_outlined,
              title: 'Manage Stud Pigs',
              onTap: () => context.push('/manage-pig'),
            ),
            _buildMenuItem(
              context,
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () {},
            ),
            _buildMenuItem(
              context,
              icon: Icons.help_outline,
              title: 'Help Center',
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

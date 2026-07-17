import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/stud_pig_repository.dart';
import '../../data/breeding_request_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../core/constants/colors.dart';

class BreederDashboardScreen extends ConsumerWidget {
  const BreederDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not authenticated')),
      );
    }

    final pigsAsync = ref.watch(breederStudPigsProvider(user.uid));
    final requestsAsync = ref.watch(breederRequestsProvider(user.uid));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Breeder Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: requestsAsync.when(
              data: (requests) {
                return pigsAsync.when(
                  data: (pigs) {
                    final int totalPigs = pigs.length;
                    final int pendingRequests = requests.where((r) => r.status == 'pending').length;
                    final int activeBookings = requests.where((r) => r.status == 'accepted').length;
                    final int completedServices = requests.where((r) => r.status == 'completed').length;
                    
                    final int aiRequests = requests.where((r) => r.serviceType == 'Artificial Insemination').length;
                    final int naturalRequests = requests.where((r) => r.serviceType == 'Natural Breeding').length;

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Overview Statistics',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.3,
                            children: [
                              _buildStatCard(
                                context,
                                title: 'Total Pigs',
                                value: '$totalPigs',
                                icon: Icons.pets,
                                color: Colors.blue.shade700,
                              ),
                              _buildStatCard(
                                context,
                                title: 'Pending Requests',
                                value: '$pendingRequests',
                                icon: Icons.pending_actions,
                                color: Colors.orange.shade700,
                              ),
                              _buildStatCard(
                                context,
                                title: 'Active Bookings',
                                value: '$activeBookings',
                                icon: Icons.assignment_turned_in,
                                color: Colors.green.shade700,
                              ),
                              _buildStatCard(
                                context,
                                title: 'Completed',
                                value: '$completedServices',
                                icon: Icons.verified,
                                color: Colors.teal.shade700,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Requests by Breeding Service',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _buildServiceTypeBreakdown(
                            context,
                            aiRequests: aiRequests,
                            naturalRequests: naturalRequests,
                          ),
                          const SizedBox(height: 24),
                          // Quick links or recent requests summary
                          if (requests.isNotEmpty) ...[
                            Text(
                              'Recent Requests Action List',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: requests.length > 3 ? 3 : requests.length,
                              itemBuilder: (context, index) {
                                final r = requests[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: AppColors.primaryLight,
                                      child: Icon(Icons.mail_outline, color: Colors.white),
                                    ),
                                    title: Text('${r.studPigName} - ${r.serviceType}'),
                                    subtitle: Text('Status: ${r.status} • Farmer: ${r.farmerName}'),
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error loading pigs: $err')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading requests: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withAlpha(20), width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ],
          ),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTypeBreakdown(
    BuildContext context, {
    required int aiRequests,
    required int naturalRequests,
  }) {
    final int total = aiRequests + naturalRequests;
    final double aiPct = total > 0 ? aiRequests / total : 0.5;
    final double naturalPct = total > 0 ? naturalRequests / total : 0.5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Artificial Insemination (AI)', style: TextStyle(fontWeight: FontWeight.w500)),
                  Text('$aiRequests requests', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              Text('${(aiPct * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: aiPct,
            color: Colors.purple.shade400,
            backgroundColor: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Natural Breeding', style: TextStyle(fontWeight: FontWeight.w500)),
                  Text('$naturalRequests requests', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              Text('${(naturalPct * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: naturalPct,
            color: Colors.orange.shade400,
            backgroundColor: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

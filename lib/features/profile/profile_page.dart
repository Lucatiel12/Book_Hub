// lib/features/profile/profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import '../auth/auth_page.dart';
import 'package:book_hub/features/settings/settings_page.dart';
import 'package:book_hub/pages/reading_history_page.dart';
import 'package:book_hub/features/profile/profile_stats_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);

    // Safe fallbacks
    final firstName =
        (authState.firstName ?? '').trim().isNotEmpty
            ? authState.firstName!
            : 'First';
    final lastName =
        (authState.lastName ?? '').trim().isNotEmpty
            ? authState.lastName!
            : 'Last';
    final fullName = '$firstName $lastName'.trim();
    final email =
        (authState.email ?? '').trim().isNotEmpty
            ? authState.email!
            : 'No email available';
    final role = (authState.role ?? 'USER').trim();
    final isAdmin = role.toUpperCase() == 'ADMIN';

    // Live profile stats
    final statsAsync = ref.watch(profileStatsProvider);
    final statsRow = statsAsync.when(
      data:
          (s) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ProfileStat(label: 'Saved', value: s.savedCount.toString()),
              _ProfileStat(
                label: 'Library',
                value: s.downloadedCount.toString(),
              ),
              _ProfileStat(label: 'History', value: s.historyCount.toString()),
            ],
          ),
      loading:
          () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: CircularProgressIndicator(),
          ),
      error: (_, __) => const Text('Failed to load stats'),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.green.shade100,
              child: const Icon(Icons.person, size: 60, color: Colors.green),
            ),
            const SizedBox(height: 12),
            Text(
              authState.isAuthenticated ? fullName : 'Anonymous User',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(email, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),

            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isAdmin ? Colors.red.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                role.toUpperCase(),
                style: TextStyle(
                  color: isAdmin ? Colors.red.shade800 : Colors.green.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Quick stats (live)
            statsRow,

            const SizedBox(height: 30),

            // User options
            _buildOptionTile(
              icon: Icons.edit,
              title: 'Edit Profile',
              onTap: () {
                // TODO: navigate to EditProfilePage
              },
            ),
            _buildOptionTile(
              icon: Icons.settings,
              title: 'Settings',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
            ),
            _buildOptionTile(
              icon: Icons.history,
              title: 'Reading History',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReadingHistoryPage()),
                );
              },
            ),

            // Admin-only section
            if (isAdmin) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Admin',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildOptionTile(
                icon: Icons.inbox_outlined,
                title: 'Manage Requests',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Open: Manage Requests')),
                  );
                },
              ),
              _buildOptionTile(
                icon: Icons.fact_check_outlined,
                title: 'Review Submissions',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Open: Review Submissions')),
                  );
                },
              ),
            ],

            _buildOptionTile(
              icon: Icons.logout,
              title: 'Log Out',
              color: Colors.red,
              onTap: () async {
                await authNotifier.logout();
                if (!context.mounted) return; // guard the same context you use
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthPage()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Reusable option tile
  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Color? color,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: color ?? Colors.green),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}

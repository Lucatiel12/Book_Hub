import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);

    // Safe fallback values
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

            // Quick stats (placeholders)
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ProfileStat(label: 'Saved', value: '24'),
                _ProfileStat(label: 'Library', value: '12'),
                _ProfileStat(label: 'Reviews', value: '8'),
              ],
            ),

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
                // TODO: navigate to SettingsPage
              },
            ),
            _buildOptionTile(
              icon: Icons.history,
              title: 'Reading History',
              onTap: () {
                // TODO: navigate to HistoryPage
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
                  // TODO: Navigator.pushNamed(context, '/admin/requests');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Open: Manage Requests')),
                  );
                },
              ),
              _buildOptionTile(
                icon: Icons.fact_check_outlined,
                title: 'Review Submissions',
                onTap: () {
                  // TODO: Navigator.pushNamed(context, '/admin/submissions');
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
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthPage()),
                    (route) => false,
                  );
                }
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

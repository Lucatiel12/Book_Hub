import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/features/auth/auth_selectors.dart';
import 'package:book_hub/features/admin/admin_dashboard_page.dart';

class AdminEntryTile extends ConsumerWidget {
  const AdminEntryTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) return const SizedBox.shrink();

    return Card(
      child: ListTile(
        leading: const Icon(Icons.admin_panel_settings, color: Colors.green),
        title: const Text('Admin'),
        subtitle: const Text('Manage submissions and requests'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
          );
        },
      ),
    );
  }
}

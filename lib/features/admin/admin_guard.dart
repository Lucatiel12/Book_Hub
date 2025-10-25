import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/features/auth/auth_provider.dart';

/// Wrap any admin screen with this guard:
///   return AdminGuard(child: Scaffold(...));
class AdminGuard extends ConsumerWidget {
  final Widget child;
  const AdminGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).role;
    if (role == 'ADMIN') return child;

    return Scaffold(
      appBar: AppBar(title: const Text('Access denied')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 12),
              const Text('Admins only'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

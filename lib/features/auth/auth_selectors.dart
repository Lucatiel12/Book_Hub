import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/features/auth/auth_provider.dart';

/// true if current user is logged in and has ADMIN role
final isAdminProvider = Provider<bool>((ref) {
  final s = ref.watch(authProvider);
  return s.isAuthenticated && (s.role?.toUpperCase() == 'ADMIN');
});

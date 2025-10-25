import 'package:book_hub/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/features/auth/auth_provider.dart';
import 'package:book_hub/pages/home_page.dart'; // ✅ add this import
import 'package:book_hub/features/auth/auth_page.dart'; // ✅ add this import

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), _checkAuth);
  }

  Future<void> _checkAuth() async {
    // Check authentication
    final isAuthed = ref.read(authProvider).isAuthenticated;
    if (!mounted) return;

    // ✅ Revert to direct navigation instead of named routes
    if (isAuthed) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(child: Icon(Icons.menu_book, color: Colors.white, size: 72)),
    );
  }
}

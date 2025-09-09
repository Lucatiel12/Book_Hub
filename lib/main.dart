// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:book_hub/services/storage/shared_prefs_provider.dart';
import 'package:book_hub/services/notifications/notification_service.dart';

// Theme & boot
import 'theme/app_theme.dart';
import 'features/onboarding/splash_page.dart';
import 'features/onboarding/onboarding_page.dart';

// Core pages
import 'features/auth/auth_page.dart';
import 'pages/home_page.dart';

// FAB flows
import 'features/requests/request_book_page.dart';
import 'features/requests/submit_book_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local notifications (Android/iOS/macOS)
  await NotificationService.instance.init();

  // Set up SharedPreferences for Riverpod
  final sp = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(sp),
        // Optionally override LRU cap for downloads:
        // downloadsMaxBytesProvider.overrideWithValue(500 * 1024 * 1024),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BookHub',
      theme: AppTheme.light,
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashPage(),
        '/onboarding': (_) => const OnboardingPage(),
        '/auth': (_) => const AuthPage(),
        '/home': (_) => const HomePage(),
        '/submitBook': (_) => const SubmitBookPage(),
        '/requestBook': (_) => const RequestBookPage(),
      },
    );
  }
}

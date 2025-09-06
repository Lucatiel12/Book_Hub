import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BookHub',
      theme: AppTheme.light, // centralized theme (no .withOpacity anywhere)
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

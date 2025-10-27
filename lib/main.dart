import 'package:book_hub/services/storage/downloaded_books_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// ---- Theme & boot
import 'theme/app_theme.dart';
import 'features/onboarding/splash_page.dart';
import 'features/onboarding/onboarding_page.dart';

// ---- Auth
import 'features/auth/auth_page.dart';

// ---- Core pages (zero-arg)
import 'pages/home_page.dart';
import 'pages/categories_page.dart';
import 'pages/library_page.dart';
import 'pages/reading_history_page.dart';
import 'pages/saved_page.dart';
import 'pages/search_page.dart';

// ---- Arg’d pages (alias to avoid any name clashes)
import 'pages/category_books_page.dart' as catpg;
import 'pages/book_details_page.dart' as bookpg;

// ---- User quick actions
import 'features/requests/user_request_book_page.dart';
import 'features/requests/user_submit_book_page.dart';

// ---- Admin
import 'features/admin/admin_submit_book_page.dart';
import 'features/admin/admin_requests_page.dart';
import 'features/admin/admin_submissions_page.dart';

// ---- Settings / services
import 'features/settings/locale_provider.dart';
import 'services/storage/shared_prefs_provider.dart';
import 'services/notifications/notification_service.dart';

// ---- Models for route args
import 'backend/models/dtos.dart' show CategoryDto;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();

  final sp = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(sp)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This triggers DownloadedBooksStore.init() one time at app startup.
    ref.watch(downloadedInitProvider);

    final locale = ref.watch(localeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BookHub',
      theme: AppTheme.light,

      // i18n
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      locale: locale,

      initialRoute: '/splash',

      // 1) Zero-arg routes go here
      routes: {
        // 🌊 Splash + onboarding + auth
        '/splash': (_) => const SplashPage(),
        '/onboarding': (_) => const OnboardingPage(),
        '/auth': (_) => const AuthPage(),

        // 🏠 Main user pages
        '/home': (_) => const HomePage(),
        '/categories': (_) => const CategoriesPage(),
        '/library': (_) => const LibraryPage(),
        '/readingHistory': (_) => const ReadingHistoryPage(),
        '/saved': (_) => const SavedPage(),
        '/search': (_) => const SearchPage(),

        // 📚 User quick actions
        '/submitBook': (_) => const SubmitBookPage(),
        '/requestBook': (_) => const RequestBookPage(),

        // 🛠️ Admin
        '/admin/submit-book': (_) => const AdminSubmitBookPage(),
        '/admin/requests': (_) => const AdminRequestsPage(), // LOOKUP
        '/admin/submissions':
            (_) => const AdminSubmissionsPage(), // CONTRIBUTION
      },

      // 2) Pages that NEED arguments go here
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/categoryBooks':
            {
              final args = settings.arguments;
              late final String categoryId;
              late final String categoryName;

              if (args is CategoryDto) {
                categoryId = args.id;
                categoryName = args.name;
              } else if (args is Map) {
                categoryId = args['id'] as String;
                categoryName = args['name'] as String;
              } else {
                throw ArgumentError('Invalid arguments for /categoryBooks');
              }

              return MaterialPageRoute(
                builder:
                    (_) => catpg.CategoryBooksPage(
                      categoryId: categoryId,
                      categoryName: categoryName,
                    ),
              );
            }

          case '/bookDetails':
            {
              final bookId = settings.arguments as String?;
              if (bookId == null || bookId.isEmpty) {
                throw ArgumentError('bookId is required for /bookDetails');
              }
              return MaterialPageRoute(
                builder: (_) => bookpg.BookDetailsPage(bookId: bookId),
              );
            }
        }
        return null; // Unknown route -> default handling
      },
    );
  }
}

// lib/pages/home_page.dart
import 'package:book_hub/backend/api_client.dart';
import 'package:book_hub/backend/models/dtos.dart' show ResourceType;
import 'package:book_hub/features/auth/auth_provider.dart';
import 'package:book_hub/features/books/providers/categories_provider.dart';
import 'package:book_hub/features/downloads/downloads_button.dart';
import 'package:book_hub/pages/categories_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backend/book_repository.dart' show UiBook;
import '../features/profile/profile_page.dart';
import '../utils/error_text.dart'; // Add import for friendlyError
import '../widgets/friendly_error.dart'; // Add import for FriendlyError
import '../widgets/offline_banner.dart';
import 'book_details_page.dart';
import 'library_page.dart';
import 'saved_page.dart';
import 'search_page.dart';

// 🔗 reading data (history/progress) – use your repo & models
import 'package:book_hub/features/reading/reading_models.dart' as rm;
import 'package:book_hub/features/reading/reading_providers.dart';

// Colors
const Color _primaryGreen = Color(0xFF4CAF50);
const Color _lightGreenBackground = Color(0xFFF0FDF0);

/// Fetch real books for the Home page
final booksProvider = FutureProvider.autoDispose<List<UiBook>>((ref) async {
  final api = ref.read(apiClientProvider);

  // Fetch first page (tweak size as needed)
  final page = await api.getBooks(page: 0, size: 20);

  // Map BookResponseDto -> UiBook used by your UI
  return page.content
      .map((b) {
        String? ebookUrl;
        for (final r in b.bookFiles) {
          if (r.type == ResourceType.EBOOK) {
            ebookUrl = r.contentUrl;
            break;
          }
        }

        return UiBook(
          id: b.id,
          title: b.title,
          author: b.author,
          description: b.description ?? '',
          coverUrl: b.coverImage,
          ebookUrl: ebookUrl,
          categoryIds: b.categoryIds,
          resources: b.bookFiles,
        );
      })
      .toList(growable: false);
});

/// Find the "Featured" category id (case-insensitive)
final featuredCategoryIdProvider = Provider.autoDispose<String?>((ref) {
  final cats = ref
      .watch(categoriesProvider)
      .maybeWhen(data: (v) => v, orElse: () => null);
  if (cats == null) return null;
  final match = cats.where((c) => c.name.toLowerCase().trim() == 'featured');
  return match.isEmpty ? null : match.first.id;
});

/// Books limited to the Featured category
final featuredOnlyBooksProvider = FutureProvider.autoDispose<List<UiBook>>((
  ref,
) async {
  final featuredId = ref.watch(featuredCategoryIdProvider);
  if (featuredId == null || featuredId.isEmpty) return const [];

  final api = ref.read(apiClientProvider);

  // Ask server to filter, but we'll still enforce locally.
  final page = await api.getBooks(page: 0, size: 100, categoryId: featuredId);

  final all = page.content
      .map((b) {
        String? ebookUrl;
        for (final r in b.bookFiles) {
          if (r.type == ResourceType.EBOOK) {
            ebookUrl = r.contentUrl;
            break;
          }
        }
        return UiBook(
          id: b.id,
          title: b.title,
          author: b.author,
          description: b.description ?? '',
          coverUrl: b.coverImage,
          ebookUrl: ebookUrl,
          categoryIds: b.categoryIds,
          resources: b.bookFiles,
        );
      })
      .toList(growable: false);

  // ✅ Guaranteed Featured-only even if backend ignores the query param.
  return all.where((b) => b.categoryIds.contains(featuredId)).toList();
});

/// Recent reading history (first 10) — uses your ReadingRepository
final readingHistoryProvider =
    FutureProvider.autoDispose<List<rm.ReadingHistoryItem>>((ref) async {
      final repo = ref.read(readingRepositoryProvider);
      final page = await repo.getHistory(
        page: 0,
        size: 10,
        sort: 'lastOpenedAt,desc',
      );
      return page.content;
    });

/// Continue Reading = history items with progress in (0,1)
final continueReadingProvider = FutureProvider.autoDispose<
  List<(rm.ReadingHistoryItem, rm.ReadingProgressDto)>
>((ref) async {
  final repo = ref.read(readingRepositoryProvider);
  final history = await ref.watch(readingHistoryProvider.future);

  // Limit how many progress calls we fire
  final head = history.take(10).toList();

  // 2.a Patch: make per-book progress fetch non-fatal
  final pairs = await Future.wait(
    head.map((h) async {
      try {
        final p = await repo.getProgress(h.bookId); // may throw 500
        return (h, p);
      } catch (_) {
        return (h, null); // 👈 swallow per-item failures
      }
    }),
  );

  final filtered =
      pairs
          .where(
            (t) => t.$2 != null && t.$2!.percent > 0.0 && t.$2!.percent < 1.0,
          )
          .map<(rm.ReadingHistoryItem, rm.ReadingProgressDto)>(
            (t) => (t.$1, t.$2!),
          )
          .toList();

  // Sort by lastOpenedAt desc (defensive; history already sorted)
  filtered.sort((a, b) {
    final da = a.$1.lastOpenedAt;
    final db = b.$1.lastOpenedAt;
    if (da == null || db == null) return 0;
    return db.compareTo(da);
  });

  return filtered;
});

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _isOffline = false;

  final List<Widget> _pages = const [
    _HomeContent(),
    SearchPage(),
    SavedPage(),
    LibraryPage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    if (_isOffline && index != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are offline. Only Library is available.'),
        ),
      );
      return;
    }
    setState(() => _selectedIndex = index);
  }

  // 2.b Patch: Add FAB helper
  Widget? _fabForTab() {
    switch (_selectedIndex) {
      case 0: // Home tab uses the + sheet
        return FloatingActionButton(
          backgroundColor: _primaryGreen,
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (_) {
                return SafeArea(
                  child: Wrap(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.upload_file,
                          color: _primaryGreen,
                        ),
                        title: const Text("Submit a Book"),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, "/submitBook");
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.edit, color: _primaryGreen),
                        title: const Text("Request a Book"),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, "/requestBook");
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      case 3: // Library tab -> no FAB here; LibraryPage can have its own
        return null;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightGreenBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Consumer(
          builder: (context, ref, _) {
            final auth = ref.watch(authProvider);
            final name = _greetingName(
              first: auth.firstName,
              email: auth.email,
            );
            return AppBar(
              elevation: 0,
              backgroundColor: Colors.white,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hi, $name!",
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const Text(
                    "What would you like to read today?",
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              actions: const [
                Icon(Icons.notifications_outlined, color: Colors.black87),
                DownloadsButton(iconColor: Color.fromARGB(255, 0, 0, 0)),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          OfflineBanner(
            onStatusChanged: (isOffline) {
              setState(() {
                _isOffline = isOffline;
                if (isOffline) _selectedIndex = 3;
              });
            },
          ),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: _primaryGreen,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: "Saved"),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: "Library",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
      // 2.b Patch: Replace the global FAB with the tab-aware helper
      floatingActionButton:
          _fabForTab(), // 👈 instead of a global FAB for all tabs
    );
  }

  String _greetingName({String? first, String? email}) {
    if (first != null && first.trim().isNotEmpty) return first.trim();
    if (email != null && email.contains('@')) {
      final prefix = email.split('@').first.trim();
      if (prefix.isNotEmpty) return prefix;
    }
    return 'there';
  }
}

// ----------------------------
// 🔹 Home Content
// ----------------------------
class _HomeContent extends ConsumerWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(featuredOnlyBooksProvider);
    final featuredId = ref.watch(featuredCategoryIdProvider);

    final catsAsync = ref.watch(categoriesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        // Invalidate and refetch
        ref.invalidate(categoriesProvider);
        ref.invalidate(featuredOnlyBooksProvider);
        ref.invalidate(readingHistoryProvider);
        ref.invalidate(continueReadingProvider);

        try {
          await ref.read(featuredOnlyBooksProvider.future);
        } catch (_) {}
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ▶ Continue Reading
            Consumer(
              builder: (context, ref, _) {
                final cont = ref.watch(continueReadingProvider);
                return cont.when(
                  loading:
                      () => const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  // 2.a Patch: Replace error text with invisible widget
                  error: (e, _) {
                    // debugPrint('continueReadingProvider error: $e');
                    return const SizedBox.shrink(); // 👈 no big error text
                  },
                  data: (items) {
                    if (items.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Continue Reading",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 220,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: items.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(width: 12),
                            itemBuilder: (_, i) {
                              final (h, p) = items[i];
                              final pct =
                                  (p.percent.clamp(0.0, 1.0) * 100).round();
                              return SizedBox(
                                width: 160,
                                child: InkWell(
                                  onTap:
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => BookDetailsPage(
                                                bookId: h.bookId,
                                              ),
                                        ),
                                      ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            color: Colors.grey.shade200,
                                            child:
                                                (h.coverImage == null ||
                                                        h.coverImage!.isEmpty)
                                                    ? const Center(
                                                      child: Icon(Icons.book),
                                                    )
                                                    : Image.network(
                                                      h.coverImage!,
                                                      fit: BoxFit.cover,
                                                      width: double.infinity,
                                                      loadingBuilder:
                                                          (c, child, loading) =>
                                                              loading == null
                                                                  ? child
                                                                  : const Center(
                                                                    child:
                                                                        CircularProgressIndicator(),
                                                                  ),
                                                      errorBuilder:
                                                          (_, __, ___) =>
                                                              const Center(
                                                                child: Icon(
                                                                  Icons.error,
                                                                ),
                                                              ),
                                                    ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        h.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: p.percent.clamp(0.0, 1.0),
                                          minHeight: 6,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$pct%',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                );
              },
            ),

            // ▶ Reading History (recently opened)
            Consumer(
              builder: (context, ref, _) {
                final hist = ref.watch(readingHistoryProvider);
                return hist.when(
                  loading:
                      () => const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  error:
                      (e, _) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: FriendlyError(
                          message: friendlyError(e),
                          onRetry: () => ref.invalidate(readingHistoryProvider),
                        ),
                      ),
                  data: (items) {
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text('No reading history yet.'),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Reading History",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 160,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: items.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(width: 12),
                            itemBuilder: (_, i) {
                              final rm.ReadingHistoryItem h = items[i];
                              return SizedBox(
                                width: 120,
                                child: InkWell(
                                  onTap:
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => BookDetailsPage(
                                                bookId: h.bookId,
                                              ),
                                        ),
                                      ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            color: Colors.grey.shade200,
                                            child:
                                                (h.coverImage == null ||
                                                        h.coverImage!.isEmpty)
                                                    ? const Center(
                                                      child: Icon(Icons.book),
                                                    )
                                                    : Image.network(
                                                      h.coverImage!,
                                                      fit: BoxFit.cover,
                                                      width: double.infinity,
                                                      loadingBuilder:
                                                          (c, child, loading) =>
                                                              loading == null
                                                                  ? child
                                                                  : const Center(
                                                                    child:
                                                                        CircularProgressIndicator(),
                                                                  ),
                                                      errorBuilder:
                                                          (_, __, ___) =>
                                                              const Center(
                                                                child: Icon(
                                                                  Icons.error,
                                                                ),
                                                              ),
                                                    ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        h.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                );
              },
            ),

            // ⭐ Featured Books
            const Text(
              "Featured Books",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),

            booksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (e, _) => FriendlyError(
                    message: friendlyError(e),
                    onRetry: () => ref.invalidate(featuredOnlyBooksProvider),
                  ),
              data: (books) {
                if (featuredId == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No "Featured" category yet. Create it in Admin → Categories.',
                    ),
                  );
                }
                if (books.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No featured books yet. Tag some books with the "Featured" category.',
                    ),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: books.length,
                  itemBuilder: (_, i) {
                    final b = books[i];
                    return InkWell(
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookDetailsPage(bookId: b.id),
                            ),
                          ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                color: Colors.grey.shade200,
                                child:
                                    (b.coverUrl == null || b.coverUrl!.isEmpty)
                                        ? const Center(child: Icon(Icons.book))
                                        : Image.network(
                                          b.coverUrl!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          loadingBuilder:
                                              (context, child, loading) =>
                                                  loading == null
                                                      ? child
                                                      : const Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      ),
                                          errorBuilder:
                                              (context, error, stack) =>
                                                  const Center(
                                                    child: Icon(Icons.error),
                                                  ),
                                        ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            b.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            b.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 20),

            // 📚 Categories
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Browse Categories",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CategoriesPage()),
                    );
                  },
                  child: const Text(
                    "View All",
                    style: TextStyle(color: _primaryGreen),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            catsAsync.when(
              loading:
                  () => const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error:
                  (e, _) => FriendlyError(
                    message: friendlyError(e),
                    onRetry: () => ref.invalidate(categoriesProvider),
                  ),
              data: (cats) {
                final top = cats.take(3).toList();
                if (top.isEmpty) return const Text('No categories yet.');
                return Column(
                  children:
                      top
                          .map(
                            (c) => _CategoryTile(
                              title: c.name,
                              books: c.bookCount ?? 0,
                              icon: Icons.category,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/categoryBooks',
                                  arguments: c,
                                );
                              },
                            ),
                          )
                          .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------
// 🔹 Reusable widgets
// ----------------------------
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: _primaryGreen.withOpacity(0.1),
          child: Icon(icon, color: _primaryGreen),
        ),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String title;
  final int books;
  final IconData icon;
  final VoidCallback? onTap;

  const _CategoryTile({
    required this.title,
    required this.books,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _primaryGreen.withOpacity(0.1),
          child: Icon(icon, color: _primaryGreen),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("$books books"),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

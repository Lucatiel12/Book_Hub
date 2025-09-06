import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity.dart'; // isOfflineProvider
import 'book_details_page.dart';

/// --- Simple book item (kept local for now) ---
class _BookItem {
  final String title;
  final String author;
  final double rating;
  final String coverUrl;
  final String category;
  final List<String>? chapters;

  const _BookItem({
    required this.title,
    required this.author,
    required this.rating,
    required this.coverUrl,
    required this.category,
    this.chapters,
  });
}

/// --- Search State ---
class _SearchState {
  final bool isLoading;
  final String query;
  final List<_BookItem> results;
  final String? error; // keep for future API errors

  const _SearchState({
    this.isLoading = false,
    this.query = '',
    this.results = const [],
    this.error,
  });

  _SearchState copyWith({
    bool? isLoading,
    String? query,
    List<_BookItem>? results,
    String? error,
  }) {
    return _SearchState(
      isLoading: isLoading ?? this.isLoading,
      query: query ?? this.query,
      results: results ?? this.results,
      error: error,
    );
  }
}

/// --- Search Controller (debounced) ---
class _SearchController extends StateNotifier<_SearchState> {
  _SearchController() : super(const _SearchState());

  Timer? _debounce;

  /// Call this from the TextField onChanged
  void onQueryChanged(String q) {
    state = state.copyWith(query: q);

    // debounce
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _performLocalSearch(q);
    });
  }

  /// Replace this with a real API later.
  /// Keep it synchronous & tiny for performance now.
  void _performLocalSearch(String q) {
    final query = q.trim().toLowerCase();

    if (query.isEmpty) {
      state = state.copyWith(results: const [], isLoading: false, error: null);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    // Minimal mock “dataset”
    const all = <_BookItem>[
      _BookItem(
        title: 'The Great Gatsby',
        author: 'F. Scott Fitzgerald',
        rating: 4.5,
        coverUrl:
            'https://upload.wikimedia.org/wikipedia/en/f/f7/TheGreatGatsby_1925jacket.jpeg',
        category: 'Classic Literature',
        chapters: ['Chapter 1', 'Chapter 2', 'Chapter 3'],
      ),
      _BookItem(
        title: 'Modern Fiction Collection',
        author: 'Various Authors',
        rating: 4.7,
        coverUrl: '',
        category: 'Fiction',
      ),
      _BookItem(
        title: 'Science Fundamentals',
        author: 'Dr. Maria Rodriguez',
        rating: 4.6,
        coverUrl: '',
        category: 'Science',
      ),
    ];

    // super fast filter
    final filtered = all
        .where((b) {
          return b.title.toLowerCase().contains(query) ||
              b.author.toLowerCase().contains(query) ||
              b.category.toLowerCase().contains(query);
        })
        .toList(growable: false);

    state = state.copyWith(results: filtered, isLoading: false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final _searchProvider =
    StateNotifierProvider.autoDispose<_SearchController, _SearchState>(
      (ref) => _SearchController(),
    );

class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);
    final state = ref.watch(_searchProvider);
    final controller = ref.read(_searchProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Placeholder for future: refetch page 1 from API
          // For now, just wait a tick to show the indicator.
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // --- Search bar ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  enabled: !isOffline,
                  onChanged: controller.onQueryChanged,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText:
                        isOffline
                            ? 'Offline — search is unavailable'
                            : 'Search books, authors, categories…',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),

            // --- Offline banner (inline) ---
            if (isOffline)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _InlineInfo(
                    icon: Icons.wifi_off,
                    text:
                        'You are offline. Try again when you have internet connection.',
                  ),
                ),
              ),

            // --- Loading indicator ---
            if (state.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),

            // --- Empty states ---
            if (!state.isLoading && state.query.isEmpty)
              const SliverToBoxAdapter(child: _EmptyHint()),

            if (!state.isLoading &&
                state.query.isNotEmpty &&
                state.results.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: const _InlineInfo(
                    icon: Icons.search_off,
                    text: 'No results. Try another keyword.',
                  ),
                ),
              ),

            // --- Results list ---
            SliverList.separated(
              itemCount: state.results.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, index) {
                final book = state.results[index];
                final isLast = index == state.results.length - 1;

                // 👇 Infinite scroll scaffold (ready for API pagination)
                if (isLast && !state.isLoading) {
                  // In the future: trigger controller.fetchNextPage()
                }

                return _BookTile(book: book);
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  final _BookItem book;
  const _BookTile({required this.book});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child:
            (book.coverUrl.isNotEmpty)
                ? Image.network(
                  book.coverUrl,
                  width: 46,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _CoverPlaceholder(),
                )
                : const _CoverPlaceholder(),
      ),
      title: Text(
        book.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${book.author} • ${book.category}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 16, color: Colors.amber),
          const SizedBox(width: 4),
          Text(book.rating.toStringAsFixed(1)),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => BookDetailsPage(
                  title: book.title,
                  author: book.author,
                  coverUrl: book.coverUrl,
                  rating: book.rating,
                  category: book.category,
                  chapters: book.chapters,
                  description:
                      'Preview description for "${book.title}". Replace with real API content.',
                ),
          ),
        );
      },
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.book, color: Colors.grey),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
      child: Column(
        children: const [
          Icon(Icons.manage_search, size: 48, color: Colors.black38),
          SizedBox(height: 12),
          Text(
            'Search for books, authors, or categories',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InlineInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'book_details_page.dart';

class CategoryBooksPage extends StatefulWidget {
  final String categoryName;
  const CategoryBooksPage({super.key, required this.categoryName});

  @override
  State<CategoryBooksPage> createState() => _CategoryBooksPageState();
}

class _CategoryBooksPageState extends State<CategoryBooksPage> {
  final _scrollController = ScrollController();

  // Paging state
  final List<_SimpleBook> _books = [];
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _pageSize = 18;

  // simple throttle for scroll events
  bool _loadQueued = false;

  @override
  void initState() {
    super.initState();
    _fetchPage(reset: true);

    _scrollController.addListener(() {
      if (_isLoadingMore || !_hasMore) return;

      // When within ~2 screens from bottom, start loading next page
      final threshold = 2 * 600; // ~2 screens worth (rough heuristic)
      final position = _scrollController.position;
      if (position.pixels + threshold >= position.maxScrollExtent) {
        // Throttle to avoid duplicate calls
        if (_loadQueued) return;
        _loadQueued = true;
        _fetchPage().whenComplete(() => _loadQueued = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await _fetchPage(reset: true);
    setState(() => _isRefreshing = false);
  }

  Future<void> _fetchPage({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _hasMore = true;
      _books.clear();
      setState(() {}); // reflect cleared UI quickly
    }

    if (!_hasMore) return;

    setState(() => _isLoadingMore = true);

    // ⏳ Simulate network latency
    await Future.delayed(const Duration(milliseconds: 600));

    // 🧪 Simulate backend responding with a page of results
    final newItems = _mockBooksFor(
      widget.categoryName,
      page: _page,
      pageSize: _pageSize,
    );

    // If fewer than pageSize, assume no more pages
    if (newItems.length < _pageSize) {
      _hasMore = false;
    }

    _books.addAll(newItems);
    _page += 1;

    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.categoryName;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child:
            _books.isEmpty && !_isLoadingMore
                ? ListView(
                  // RefreshIndicator needs a scrollable even when empty
                  children: const [
                    SizedBox(height: 80),
                    Center(
                      child: Text(
                        "No books in this category yet.",
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ],
                )
                : CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(12),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3, // compact & efficient
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.58, // cover-focused layout
                            ),
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final b = _books[i];
                          return _BookTile(
                            title: b.title,
                            author: b.author,
                            coverUrl: b.coverUrl,
                            rating: b.rating,
                            category: title,
                          );
                        }, childCount: _books.length),
                      ),
                    ),

                    // Bottom loader / “no more” message
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child:
                              _isLoadingMore
                                  ? const SizedBox(
                                    height: 28,
                                    width: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : (!_hasMore
                                      ? const Text(
                                        "That's all for now",
                                        style: TextStyle(color: Colors.black54),
                                      )
                                      : const SizedBox.shrink()),
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  // ---- Mock paginated data generator (replace with API later) ----
  List<_SimpleBook> _mockBooksFor(
    String category, {
    required int page,
    required int pageSize,
  }) {
    // A tiny pool of covers (placeholder images for demo)
    const covers = [
      'https://picsum.photos/200/300?1',
      'https://picsum.photos/200/300?2',
      'https://picsum.photos/200/300?3',
      'https://picsum.photos/200/300?4',
      'https://picsum.photos/200/300?5',
      'https://picsum.photos/200/300?6',
    ];

    final seed = category.hashCode.abs();
    // For demo: pretend there are only ~60 books max per category
    final total = 60;
    final start = (page - 1) * pageSize;
    final end = (start + pageSize).clamp(0, total);

    if (start >= total) return const [];

    return List.generate(end - start, (offset) {
      final i = start + offset;
      return _SimpleBook(
        title: '$category Book ${i + 1}',
        author: 'Author ${(seed + i) % 97}',
        coverUrl: covers[i % covers.length],
        rating: 3.5 + (((seed + i) % 15) / 10.0), // 3.5..5.0
      );
    });
  }
}

// ---- Compact, fast book card ----
class _BookTile extends StatelessWidget {
  final String title;
  final String author;
  final String coverUrl;
  final double rating;
  final String category;

  const _BookTile({
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.rating,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => BookDetailsPage(
                  title: title,
                  author: author,
                  coverUrl: coverUrl,
                  rating: rating,
                  category: category,
                  description:
                      'A placeholder description for "$title" in $category.',
                ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover
          AspectRatio(
            aspectRatio: 0.68, // book cover ratio
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                coverUrl,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low, // perf-friendly
                errorBuilder:
                    (_, __, ___) => Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.book, size: 40, color: Colors.grey),
                      ),
                    ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Title
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
          ),
          const SizedBox(height: 2),
          // Author
          Text(
            author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54, fontSize: 11),
          ),
          const SizedBox(height: 2),
          // Rating
          Row(
            children: [
              const Icon(Icons.star, size: 14, color: Colors.amber),
              const SizedBox(width: 3),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---- Minimal book model for this page ----
class _SimpleBook {
  final String title;
  final String author;
  final String coverUrl;
  final double rating;
  const _SimpleBook({
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.rating,
  });
}

// lib/pages/category_books_page.dart
import 'dart:async';
import 'package:flutter/material.dart';

import 'book_details_page.dart';
import 'package:book_hub/backend/book_repository.dart' show UiBook;
import 'package:book_hub/backend/models/dtos.dart' show ResourceDto;

class CategoryBooksPage extends StatefulWidget {
  final String categoryName;
  const CategoryBooksPage({super.key, required this.categoryName});

  @override
  State<CategoryBooksPage> createState() => _CategoryBooksPageState();
}

class _CategoryBooksPageState extends State<CategoryBooksPage> {
  final _scrollController = ScrollController();

  // Paging state
  final List<UiBook> _books = [];
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
      final threshold = 2 * 600; // rough heuristic
      final position = _scrollController.position;
      if (position.pixels + threshold >= position.maxScrollExtent) {
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
                              crossAxisCount: 3, // compact
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.58, // cover-focused layout
                            ),
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final book = _books[i];
                          return _BookTile(book: book);
                        }, childCount: _books.length),
                      ),
                    ),

                    // Bottom loader / "no more" message
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
  List<UiBook> _mockBooksFor(
    String category, {
    required int page,
    required int pageSize,
  }) {
    const covers = [
      'https://picsum.photos/200/300?1',
      'https://picsum.photos/200/300?2',
      'https://picsum.photos/200/300?3',
      'https://picsum.photos/200/300?4',
      'https://picsum.photos/200/300?5',
      'https://picsum.photos/200/300?6',
    ];

    // Pretend there are ~60 books max per category
    final total = 60;
    final start = (page - 1) * pageSize;
    final end = (start + pageSize).clamp(0, total);

    if (start >= total) return const [];

    return List.generate(end - start, (offset) {
      final i = start + offset;
      return UiBook(
        id: '${category}_$i',
        title: '$category Book ${i + 1}',
        author: 'Author $i',
        description: 'Description for $category Book ${i + 1}',
        coverUrl: covers[i % covers.length],
        ebookUrl: null,
        categoryIds: const [], // mock: no real IDs
        resources: const <ResourceDto>[], // mock: no resources
      );
    });
  }
}

// ---- Compact book card ----
class _BookTile extends StatelessWidget {
  final UiBook book;

  const _BookTile({required this.book});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BookDetailsPage(bookId: book.id)),
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
              child:
                  (book.coverUrl?.isNotEmpty ?? false)
                      ? Image.network(
                        book.coverUrl!,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                      : _buildPlaceholder(),
            ),
          ),
          const SizedBox(height: 6),
          // Title
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
          ),
          const SizedBox(height: 2),
          // Author
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.book, size: 40, color: Colors.grey),
      ),
    );
  }
}

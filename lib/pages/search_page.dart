// lib/pages/search_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connectivity.dart'; // isOfflineProvider
import 'book_details_page.dart';

// backend types
import 'package:book_hub/backend/book_repository.dart' show UiBook;
import 'package:book_hub/backend/models/dtos.dart'
    show CategoryDto, ResourceDto, ResourceType;

// search + categories providers
import 'package:book_hub/features/books/providers/search_providers.dart';
import 'package:book_hub/features/books/providers/categories_provider.dart';

// saved / downloaded badges
import 'package:book_hub/features/books/providers/saved_downloaded_providers.dart';

class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isOffline = ref.watch(isOfflineProvider);

    // typed providers
    final results = ref.watch(
      searchResultsProvider,
    ); // AsyncValue<({List<UiBook> items, int page, int totalPages})>
    final query = ref.watch(searchQueryProvider);
    final selectedCategoryId = ref.watch(selectedCategoryIdProvider);

    final cats = ref.watch(categoriesProvider);

    void updateParams(SearchParams Function(SearchParams) f) {
      final current = ref.read(searchParamsProvider);
      ref.read(searchParamsProvider.notifier).state = f(current);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.search),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          // --- Search bar ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              enabled: !isOffline,
              onChanged: (text) {
                updateParams((p) => p.copyWith(query: text, page: 0));
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText:
                    isOffline
                        ? l10n.searchOfflineUnavailable
                        : (query.isEmpty
                            ? l10n.searchHint
                            : l10n.searchingFor(query)),
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

          // --- Category chips ---
          cats.when(
            data:
                (list) => _CategoryChips(
                  list: list,
                  selectedId: selectedCategoryId,
                  onSelect:
                      (id) => updateParams(
                        (p) => p.copyWith(categoryId: id, page: 0),
                      ),
                ),
            loading: () => const SizedBox(height: 4),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // --- Offline banner (inline) ---
          if (isOffline)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _InlineInfo(
                icon: Icons.wifi_off,
                text: l10n.offlineMessage,
              ),
            ),

          const SizedBox(height: 8),

          // --- Results area ---
          Expanded(
            child: results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (e, _) => ListView(
                    children: [
                      const SizedBox(height: 40),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _InlineInfo(
                          icon: Icons.error_outline,
                          text: l10n.searchFailed(e.toString()),
                        ),
                      ),
                    ],
                  ),
              data: (r) {
                final items = r.items;
                final page = r.page;
                final totalPages = r.totalPages;

                if (query.trim().isEmpty && items.isEmpty) {
                  return const _EmptyHint();
                }
                if (query.trim().isNotEmpty && items.isEmpty) {
                  return ListView(
                    children: [
                      const SizedBox(height: 40),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _InlineInfo(
                          icon: Icons.search_off,
                          text: l10n.noResultsTryAnotherKeyword,
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 0),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (context, index) {
                          final book = items[index];
                          return _BookTile(book: book);
                        },
                      ),
                    ),
                    // --- Pagination controls ---
                    if (totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.paginationStatus(page + 1, totalPages),
                              style: const TextStyle(color: Colors.black54),
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  icon: const Icon(
                                    Icons.arrow_back_ios,
                                    size: 16,
                                  ),
                                  label: Text(l10n.previous),
                                  onPressed:
                                      page > 0
                                          ? () => updateParams(
                                            (p) => p.copyWith(page: page - 1),
                                          )
                                          : null,
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  icon: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                  ),
                                  label: Text(l10n.next),
                                  onPressed:
                                      (page + 1) < totalPages
                                          ? () => updateParams(
                                            (p) => p.copyWith(page: page + 1),
                                          )
                                          : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BookTile extends ConsumerWidget {
  final UiBook book;
  const _BookTile({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaved = ref.watch(isBookSavedProvider(book.id));
    final isDownloadedAsync = ref.watch(isBookDownloadedProvider(book.id));

    String _thumb() {
      if ((book.coverUrl ?? '').isNotEmpty) return book.coverUrl!;
      final img = book.resources.firstWhere(
        (r) => r.type == ResourceType.IMAGE,
        orElse:
            () =>
                book.resources.isNotEmpty
                    ? book.resources.first
                    : ResourceDto(type: ResourceType.DOCUMENT, contentUrl: ''),
      );
      return img.contentUrl;
    }

    final thumb = _thumb();

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child:
            thumb.isNotEmpty
                ? Image.network(
                  thumb,
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
      subtitle: Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isDownloadedAsync.maybeWhen(
            data:
                (d) =>
                    d
                        ? const Icon(
                          Icons.check_circle,
                          size: 18,
                          color: Colors.green,
                        )
                        : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          if (isSaved)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.bookmark, size: 18, color: Colors.amber),
            ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BookDetailsPage(bookId: book.id)),
        );
      },
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final List<CategoryDto> list;
  final String? selectedId;
  final void Function(String? id) onSelect;
  const _CategoryChips({
    required this.list,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          final c = list[i];
          final isSel = c.id == selectedId;
          return ChoiceChip(
            label: Text('${c.name} (${c.bookCount})'),
            selected: isSel,
            onSelected: (v) => onSelect(v ? c.id : null),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: list.length,
      ),
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
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      children: [
        const SizedBox(height: 48),
        const Icon(Icons.manage_search, size: 48, color: Colors.black38),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.searchEmptyHint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      ],
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

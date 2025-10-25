import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/backend/backend_providers.dart';
import 'package:book_hub/backend/models/search_result.dart';

class SearchParams {
  final String query;
  final String? categoryId;
  final int page;
  final int size;
  const SearchParams({
    this.query = '',
    this.categoryId,
    this.page = 0,
    this.size = 20,
  });

  SearchParams copyWith({
    String? query,
    String? categoryId,
    int? page,
    int? size,
  }) => SearchParams(
    query: query ?? this.query,
    categoryId: categoryId ?? this.categoryId,
    page: page ?? this.page,
    size: size ?? this.size,
  );
}

final searchParamsProvider = StateProvider<SearchParams>(
  (_) => const SearchParams(),
);

// Handy selectors
final searchQueryProvider = Provider<String>(
  (ref) => ref.watch(searchParamsProvider).query,
);
final selectedCategoryIdProvider = Provider<String?>(
  (ref) => ref.watch(searchParamsProvider).categoryId,
);

final searchResultsProvider = FutureProvider.autoDispose<SearchResult>((
  ref,
) async {
  final repo = ref.watch(bookRepositoryProvider);
  final p = ref.watch(searchParamsProvider);

  // tiny debounce
  await Future<void>.delayed(const Duration(milliseconds: 200));

  // PageResult<UiBook>
  final pageResult = await repo.search(
    query: p.query,
    categoryId: p.categoryId,
    page: p.page,
    size: p.size,
  );

  return SearchResult(
    items: pageResult.items,
    page: pageResult.pageNumber,
    totalPages: pageResult.totalPages,
  );
});

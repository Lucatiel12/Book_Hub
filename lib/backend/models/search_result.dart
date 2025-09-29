import 'package:book_hub/backend/book_repository.dart' show UiBook;

class SearchResult {
  final List<UiBook> items;
  final int page;
  final int totalPages;

  const SearchResult({
    required this.items,
    required this.page,
    required this.totalPages,
  });
}

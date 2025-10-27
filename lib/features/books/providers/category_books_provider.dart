import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/backend/api_client.dart';
import 'package:book_hub/backend/models/dtos.dart' show ResourceType;
import 'package:book_hub/backend/book_repository.dart' show UiBook;

/// Fetches books, then filters locally by [categoryId].
/// Safe and isolated — does not affect other parts of the app.
final categoryBooksProvider = FutureProvider.family<List<UiBook>, String>((
  ref,
  categoryId,
) async {
  ref.keepAlive();

  final api = ref.read(apiClientProvider);

  // Fetch a large enough page since backend doesn’t filter yet.
  final page = await api.getBooks(page: 0, size: 200);

  // Client-side filter
  final filtered = page.content.where((b) {
    final ids = b.categoryIds;
    return ids.map((e) => e.toString()).contains(categoryId.toString());
  });

  // Convert to UiBook list
  return filtered
      .map((b) {
        String? ebookUrl;
        final files = b.bookFiles;
        for (final r in files) {
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
          resources: files,
        );
      })
      .toList(growable: false);
});

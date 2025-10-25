import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/backend/api_client.dart';
import 'package:book_hub/backend/models/dtos.dart' show ResourceType;
import 'package:book_hub/backend/book_repository.dart' show UiBook;
import 'book_details_page.dart';

const Color _lightGreenBackground = Color(0xFFF0FDF0);

/// Provider to fetch books by categoryId
final categoryBooksProvider = FutureProvider.family<List<UiBook>, String>((
  ref,
  categoryId,
) async {
  ref.keepAlive();

  final api = ref.read(apiClientProvider);
  final page = await api.getBooks(page: 0, size: 20, categoryId: categoryId);

  // Map DTOs to UiBook
  return page.content
      .map((b) {
        String? ebookUrl;
        // Assuming b.bookFiles is non-nullable list based on DTO definition.
        // If it can be null, use: final files = b.bookFiles ?? const [];
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

class CategoryBooksPage extends ConsumerWidget {
  final String categoryId;
  final String categoryName;

  const CategoryBooksPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(categoryBooksProvider(categoryId));

    return Scaffold(
      backgroundColor: _lightGreenBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          categoryName,
          style: const TextStyle(color: Colors.black87),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: RefreshIndicator(
        onRefresh:
            () async => ref.invalidate(categoryBooksProvider(categoryId)),
        child: booksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (err, _) => ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Column(
                      children: [
                        Text('Failed to load books: $err'),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed:
                              () => ref.invalidate(
                                categoryBooksProvider(categoryId),
                              ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          data: (books) {
            if (books.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'No books found in this category.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookDetailsPage(bookId: b.id),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
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
                                            (c, child, loading) =>
                                                loading == null
                                                    ? child
                                                    : const Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                        errorBuilder:
                                            (c, _, __) => const Center(
                                              child: Icon(Icons.error),
                                            ),
                                      ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
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
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

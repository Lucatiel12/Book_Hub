// lib/features/books/providers/books_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/backend/api_client.dart';
import 'package:book_hub/backend/models/dtos.dart';

/// Pass null for "all books" (home), or a categoryId for filtered list
final booksProvider = FutureProvider.family<List<BookResponseDto>, String?>((
  ref,
  categoryId,
) async {
  final api = ref.read(apiClientProvider);
  final page = await api.getBooks(page: 0, size: 30, categoryId: categoryId);
  return page.content;
});

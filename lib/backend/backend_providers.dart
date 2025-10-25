// lib/backend/backend_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'book_repository.dart';
import 'models/dtos.dart';

/// Reuse the ApiClient from api_client.dart:
// ignore: unintended_html_in_doc_comment
/// final apiClientProvider = Provider<ApiClient>(...)  // already defined there

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final api = ref.read(apiClientProvider);
  return BookRepository(api);
});

/// Simple categories list (first page from backend).
final categoriesProvider = FutureProvider<List<CategoryDto>>((ref) async {
  final api = ref.read(apiClientProvider);
  return api.getCategories();
});

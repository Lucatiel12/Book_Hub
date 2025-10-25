import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/backend/api_client.dart';
import 'package:book_hub/backend/models/dtos.dart';

/// Simple list of all categories (page 0..n concatenated if needed)
final categoriesProvider = FutureProvider<List<CategoryDto>>((ref) async {
  final api = ref.read(apiClientProvider);
  // grab up to 200; adjust if you expect more
  final list = await api.getCategories(page: 0, size: 200);
  return list;
});

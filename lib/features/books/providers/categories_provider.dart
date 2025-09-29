import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/backend/book_repository.dart';
import 'package:book_hub/backend/models/dtos.dart';
import 'package:book_hub/backend/backend_providers.dart';

final categoriesProvider = FutureProvider<List<CategoryDto>>((ref) async {
  final repo = ref.watch(bookRepositoryProvider);
  return repo.categories();
});

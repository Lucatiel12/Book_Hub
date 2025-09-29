import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/services/storage/saved_books_store.dart';
import 'package:book_hub/features/books/providers/saved_downloaded_providers.dart'; // 👈 bring this in
import 'package:book_hub/features/profile/profile_stats_provider.dart';

class SavedBooksManager {
  SavedBooksManager(this.ref, this.store);
  final Ref ref;
  final SavedBooksStore store;

  Future<void> save(String bookId) async {
    await store.save(bookId);
    ref.invalidate(isBookSavedProvider(bookId));
    ref.invalidate(profileStatsProvider);
  }

  Future<void> unsave(String bookId) async {
    await store.unsave(bookId);
    ref.invalidate(isBookSavedProvider(bookId));
    ref.invalidate(profileStatsProvider);
  }

  Future<void> toggle(String bookId) async {
    await store.toggle(bookId);
    ref.invalidate(isBookSavedProvider(bookId));
    ref.invalidate(profileStatsProvider);
  }

  bool isSaved(String bookId) => store.isSaved(bookId);

  Set<String> current() => store.getAll();
}

final savedBooksManagerProvider = Provider<SavedBooksManager>((ref) {
  final store = ref.watch(savedBooksStoreProvider);
  return SavedBooksManager(ref, store);
});

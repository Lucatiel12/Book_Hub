import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/services/storage/saved_books_store.dart';

class SavedBooksManager {
  final SavedBooksStore _store;
  SavedBooksManager(this._store);

  Set<String> current() => _store.getAll();
  bool isSaved(String id) => _store.isSaved(id);

  Future<void> toggle(String id) => _store.toggle(id);
  Future<void> save(String id) => _store.save(id);
  Future<void> unsave(String id) => _store.unsave(id);

  Future<void> importLegacy(Iterable<String> ids) => _store.importLegacy(ids);
}

final savedBooksManagerProvider = Provider<SavedBooksManager>((ref) {
  final store = ref.watch(savedBooksStoreProvider);
  return SavedBooksManager(store);
});

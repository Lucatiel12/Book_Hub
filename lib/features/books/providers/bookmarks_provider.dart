import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/storage/bookmarks_store.dart';

final bookmarksProvider = StateNotifierProvider.family<
  BookmarksNotifier,
  AsyncValue<List<Bookmark>>,
  String
>((ref, bookId) {
  final store = ref.watch(bookmarksStoreProvider);
  return BookmarksNotifier(store, bookId)..refresh();
});

class BookmarksNotifier extends StateNotifier<AsyncValue<List<Bookmark>>> {
  BookmarksNotifier(this._store, this._bookId) : super(const AsyncLoading());
  final BookmarksStore _store;
  final String _bookId;

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final list = await _store.getBookmarks(_bookId);
      state = AsyncData(list);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> add(int position, {String note = ''}) async {
    await _store.addBookmark(_bookId, Bookmark(position: position, note: note));
    await refresh();
  }

  Future<void> removeAt(int index) async {
    await _store.removeAt(_bookId, index);
    await refresh();
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/managers/saved_books_manager.dart';
import 'package:book_hub/managers/downloaded_books_manager.dart';
import 'package:book_hub/services/storage/downloaded_books_store.dart';
import 'package:book_hub/features/profile/profile_stats_provider.dart';
import 'package:book_hub/features/downloads/download_controller.dart';

// ===== Saved state for a specific book (sync)
final isBookSavedProvider = Provider.family<bool, String>((ref, bookId) {
  final mgr = ref.watch(savedBooksManagerProvider);
  return mgr.isSaved(bookId);
});

// ===== Downloaded state for a specific book (async, per-book)
final isBookDownloadedProvider = FutureProvider.family<bool, String>((
  ref,
  bookId,
) async {
  final store = ref.read(downloadedBooksStoreProvider); // read, not watch
  final entry = await store.getByBookId(bookId);
  return entry != null;
});

// ===== AsyncNotifier for the downloads list (Library)
class DownloadedListNotifier extends AsyncNotifier<List<DownloadEntry>> {
  DownloadedBooksStore get _store => ref.read(downloadedBooksStoreProvider);
  DownloadedBooksManager get _manager =>
      ref.read(downloadedBooksManagerProvider);

  @override
  Future<List<DownloadEntry>> build() async {
    return _store.list();
  }

  // Pull-to-refresh / programmatic refresh
  Future<void> refreshList() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _store.list());
  }

  // Optimistic delete (updates UI instantly, then persists)
  Future<void> remove(String bookId) async {
    final previous = state.value ?? const <DownloadEntry>[];
    // optimistic UI
    state = AsyncData(previous.where((e) => e.bookId != bookId).toList());

    try {
      await _manager.delete(bookId);
      // per-book + stats invalidations
      ref.invalidate(isBookDownloadedProvider(bookId));
      ref.invalidate(profileStatsProvider);
      // clear any transient download state
      ref.read(downloadControllerProvider.notifier).clearFor(bookId);
    } catch (e) {
      // rollback on failure
      state = AsyncData(previous);
      rethrow;
    }
  }

  // Import (copy + index) a local file and insert into list
  Future<DownloadEntry> importLocal({
    required String sourcePath,
    String? title,
    String? author,
    String? coverUrl,
  }) async {
    final entry = await _manager.importLocalFile(
      sourcePath: sourcePath,
      title: title,
      author: author,
      coverUrl: coverUrl,
    );

    final current = state.value ?? const <DownloadEntry>[];
    state = AsyncData(<DownloadEntry>[entry, ...current]);

    ref.invalidate(isBookDownloadedProvider(entry.bookId));
    ref.invalidate(profileStatsProvider);
    return entry;
  }
}

final downloadedListProvider =
    AsyncNotifierProvider<DownloadedListNotifier, List<DownloadEntry>>(
      () => DownloadedListNotifier(),
    );

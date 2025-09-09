import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/managers/saved_books_manager.dart';
import 'package:book_hub/managers/downloaded_books_manager.dart';
import 'package:book_hub/services/storage/downloaded_books_store.dart';

/// saved state for a specific book (sync)
final isBookSavedProvider = Provider.family<bool, String>((ref, bookId) {
  final mgr = ref.watch(savedBooksManagerProvider);
  return mgr.isSaved(bookId);
});

/// downloaded state for a specific book (async)
final isBookDownloadedProvider = FutureProvider.family<bool, String>((
  ref,
  bookId,
) async {
  final mgr = ref.watch(downloadedBooksManagerProvider);
  return mgr.isDownloaded(bookId);
});

/// list downloads for a Downloads screen
final downloadedListProvider = FutureProvider<List<DownloadEntry>>((ref) {
  final mgr = ref.watch(downloadedBooksManagerProvider);
  return mgr.list();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/models/history_entry.dart';
import 'package:book_hub/services/storage/reading_history_store.dart';

class ReadingHistoryController
    extends StateNotifier<AsyncValue<List<HistoryEntry>>> {
  final Ref ref;
  ReadingHistoryController(this.ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final list = await ref.read(readingHistoryStoreProvider).getAll();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logOpen({
    required String bookId,
    required String title,
    required String author,
    String? coverUrl,
    required int chapterIndex,
    required double scrollProgress,
  }) async {
    final entry = HistoryEntry(
      bookId: bookId,
      title: title,
      author: author,
      coverUrl: coverUrl,
      openedAtMillis: DateTime.now().millisecondsSinceEpoch,
      chapterIndex: chapterIndex,
      scrollProgress: scrollProgress.clamp(0.0, 1.0),
    );
    await ref.read(readingHistoryStoreProvider).upsert(entry);
    await refresh();
  }

  Future<void> remove(String bookId) async {
    await ref.read(readingHistoryStoreProvider).remove(bookId);
    await refresh();
  }

  Future<void> clearAll() async {
    await ref.read(readingHistoryStoreProvider).clear();
    await refresh();
  }
}

final readingHistoryProvider = StateNotifierProvider<
  ReadingHistoryController,
  AsyncValue<List<HistoryEntry>>
>((ref) => ReadingHistoryController(ref));

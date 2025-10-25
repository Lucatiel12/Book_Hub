import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/features/reading/reading_providers.dart';
import 'package:book_hub/features/reading/reading_models.dart';
import 'package:book_hub/services/storage/reading_history_store.dart';
import 'package:book_hub/models/history_entry.dart';

/// Converts local HistoryEntry -> server-like ReadingHistoryItem for UI reuse.
ReadingHistoryItem _fromLocal(HistoryEntry e) => ReadingHistoryItem(
  bookId: e.bookId,
  title: e.title,
  coverImage: e.coverUrl ?? '',
  lastOpenedAt: DateTime.fromMillisecondsSinceEpoch(e.openedAtMillis),
);

class ReadingHistoryController
    extends StateNotifier<AsyncValue<List<ReadingHistoryItem>>> {
  final Ref ref;

  // paging (server)
  int _page = 0;
  final int _size = 20;
  final String _sort = 'lastOpenedAt,desc';
  bool _last = false;
  bool _loading = false;

  // offline flag (exposed for UI hints)
  bool _offline = false;
  bool get isOffline => _offline;

  ReadingHistoryController(this.ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    state = const AsyncValue.loading();
    try {
      _page = 0;
      _last = false;
      _offline = false;

      final repo = ref.read(readingRepositoryProvider);
      final pageObj = await repo.getHistory(
        page: _page,
        size: _size,
        sort: _sort,
      );

      _page = pageObj.number + 1;
      _last = pageObj.last;
      state = AsyncValue.data(pageObj.content);
    } catch (e, st) {
      // 🔁 OFFLINE FALLBACK
      try {
        final local = await ref.read(readingHistoryStoreProvider).getAll();
        _offline = true;
        _last = true; // no pagination offline
        state = AsyncValue.data(local.map(_fromLocal).toList());
      } catch (_) {
        state = AsyncValue.error(e, st);
      }
    } finally {
      _loading = false;
    }
  }

  Future<void> loadMore() async {
    if (_loading || _last || _offline) return; // no paging offline
    _loading = true;
    try {
      final current = state.value ?? const <ReadingHistoryItem>[];
      final repo = ref.read(readingRepositoryProvider);
      final pageObj = await repo.getHistory(
        page: _page,
        size: _size,
        sort: _sort,
      );
      _page = pageObj.number + 1;
      _last = pageObj.last;
      state = AsyncValue.data([...current, ...pageObj.content]);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      _loading = false;
    }
  }

  /// Log open to server when online; always upsert to local for offline resilience.
  Future<void> logOpen({
    required String bookId,
    String? title,
    String? author,
    String? coverUrl,
    int? chapterIndex,
    double? scrollProgress,
  }) async {
    // Best-effort server log (readers already do POST /history themselves)
    try {
      final repo = ref.read(readingRepositoryProvider);
      await repo.logHistory(bookId);
    } catch (_) {
      // ignore
    }

    // Always upsert local
    if (title != null || author != null || coverUrl != null) {
      final entry = HistoryEntry(
        bookId: bookId,
        title: title ?? '',
        author: author ?? '',
        coverUrl: coverUrl,
        openedAtMillis: DateTime.now().millisecondsSinceEpoch,
        chapterIndex: (chapterIndex ?? 0).clamp(0, 1 << 20),
        scrollProgress: (scrollProgress ?? 0).clamp(0.0, 1.0),
      );
      await ref.read(readingHistoryStoreProvider).upsert(entry);
    }
  }

  /// Local-only (no server delete in Swagger)
  Future<void> remove(String bookId) async {
    await ref.read(readingHistoryStoreProvider).remove(bookId);
    await refresh(); // will show updated local if offline / server if online
  }

  /// Local-only (no server clear in Swagger)
  Future<void> clearAll() async {
    await ref.read(readingHistoryStoreProvider).clear();
    await refresh();
  }
}

final readingHistoryProvider = StateNotifierProvider<
  ReadingHistoryController,
  AsyncValue<List<ReadingHistoryItem>>
>((ref) => ReadingHistoryController(ref));

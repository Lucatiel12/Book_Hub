import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/services/storage/shared_prefs_provider.dart';
import 'package:book_hub/models/history_entry.dart';

const _kHistoryKey = 'reading_history_v1';
const _kMaxHistory = 200; // keep the last 200 opens

class ReadingHistoryStore {
  final SharedPreferences _sp;
  ReadingHistoryStore(this._sp);

  Future<int> count() async {
    final raw = _sp.getString(_kHistoryKey);
    if (raw == null || raw.isEmpty) return 0;
    try {
      final list = HistoryEntry.decodeList(raw);
      return list.length;
    } catch (_) {
      return 0;
    }
  }

  Future<List<HistoryEntry>> getAll() async {
    final raw = _sp.getString(_kHistoryKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = HistoryEntry.decodeList(raw);
      // newest first
      list.sort((a, b) => b.openedAtMillis.compareTo(a.openedAtMillis));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> upsert(HistoryEntry entry) async {
    final list = await getAll();
    // remove duplicate for same bookId
    list.removeWhere((e) => e.bookId == entry.bookId);
    // insert at top
    list.insert(0, entry);
    if (list.length > _kMaxHistory) list.removeRange(_kMaxHistory, list.length);
    await _sp.setString(_kHistoryKey, HistoryEntry.encodeList(list));
  }

  Future<void> remove(String bookId) async {
    final list = await getAll();
    list.removeWhere((e) => e.bookId == bookId);
    await _sp.setString(_kHistoryKey, HistoryEntry.encodeList(list));
  }

  Future<void> clear() async {
    await _sp.remove(_kHistoryKey);
  }
}

final readingHistoryStoreProvider = Provider<ReadingHistoryStore>((ref) {
  final sp = ref.watch(sharedPrefsProvider);
  return ReadingHistoryStore(sp);
});

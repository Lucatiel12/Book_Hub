import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'reader_models.dart';

class ReaderBookmarksStore {
  ReaderBookmarksStore(this._sp);
  final SharedPreferences _sp;

  String _listKey(String bookId) => 'reader_bm_list_$bookId';
  String _lastKey(String bookId) => 'reader_last_$bookId';

  Future<List<ReaderBookmark>> list(String bookId) async {
    final raw = _sp.getString(_listKey(bookId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final dec =
          (json.decode(raw) as List)
              .cast<Map>()
              .map((m) => ReaderBookmark.fromJson(m.cast<String, dynamic>()))
              .toList();
      dec.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return dec;
    } catch (_) {
      return [];
    }
  }

  Future<void> add(ReaderBookmark bm) async {
    final items = await list(bm.bookId);
    items.insert(0, bm);
    await _sp.setString(
      _listKey(bm.bookId),
      json.encode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> removeAt(String bookId, int index) async {
    final items = await list(bookId);
    if (index < 0 || index >= items.length) return;
    items.removeAt(index);
    await _sp.setString(
      _listKey(bookId),
      json.encode(items.map((e) => e.toJson()).toList()),
    );
  }

  // Last position (for auto-resume)
  Future<void> setLast(String bookId, ReaderBookmark bm) async {
    await _sp.setString(_lastKey(bookId), json.encode(bm.toJson()));
  }

  Future<ReaderBookmark?> getLast(String bookId) async {
    final raw = _sp.getString(_lastKey(bookId));
    if (raw == null || raw.isEmpty) return null;
    try {
      return ReaderBookmark.fromJson(
        (json.decode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }
}

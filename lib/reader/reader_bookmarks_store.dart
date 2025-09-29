// lib/reader/reader_bookmarks_store.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'reader_models.dart' as rm; // 👈 alias to avoid name clashes

class ReaderBookmarksStore {
  ReaderBookmarksStore(this._sp);
  final SharedPreferences _sp;

  String _listKey(String bookId) => 'reader_bm_list_$bookId';
  String _lastKey(String bookId) => 'reader_last_$bookId';

  /// Return all bookmarks for a given book, sorted by createdAt desc.
  Future<List<rm.ReaderBookmark>> list(String bookId) async {
    final raw = _sp.getString(_listKey(bookId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final dec =
          (json.decode(raw) as List)
              .cast<Map>()
              .map((m) => rm.ReaderBookmark.fromJson(m.cast<String, dynamic>()))
              .toList();
      dec.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return dec;
    } catch (_) {
      return [];
    }
  }

  /// Add a new bookmark to the list.
  Future<void> add(rm.ReaderBookmark bm) async {
    final items = await list(bm.bookId);
    items.insert(0, bm);
    await _sp.setString(
      _listKey(bm.bookId),
      json.encode(items.map((e) => e.toJson()).toList()),
    );
  }

  /// Remove bookmark at [index].
  Future<void> removeAt(String bookId, int index) async {
    final items = await list(bookId);
    if (index < 0 || index >= items.length) return;
    items.removeAt(index);
    await _sp.setString(
      _listKey(bookId),
      json.encode(items.map((e) => e.toJson()).toList()),
    );
  }

  /// Save the "last position" for auto-resume.
  Future<void> setLast(String bookId, rm.ReaderBookmark bm) async {
    await _sp.setString(_lastKey(bookId), json.encode(bm.toJson()));
  }

  /// Get the last position (for auto-resume).
  Future<rm.ReaderBookmark?> getLast(String bookId) async {
    final raw = _sp.getString(_lastKey(bookId));
    if (raw == null || raw.isEmpty) return null;
    try {
      return rm.ReaderBookmark.fromJson(
        (json.decode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }
}

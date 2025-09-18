import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shared_prefs_provider.dart';

class Bookmark {
  final int position; // e.g., page index or byte offset
  final String note; // optional note
  final DateTime createdAt;
  Bookmark({required this.position, this.note = '', DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'position': position,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
  };

  static Bookmark fromJson(Map<String, dynamic> j) => Bookmark(
    position: j['position'] as int,
    note: (j['note'] as String?) ?? '',
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}

final bookmarksStoreProvider = Provider<BookmarksStore>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return BookmarksStore(prefs);
});

class BookmarksStore {
  BookmarksStore(this._prefs);
  final SharedPreferences _prefs;

  String _key(String bookId) => 'bookmarks_$bookId';

  Future<List<Bookmark>> getBookmarks(String bookId) async {
    final raw = _prefs.getStringList(_key(bookId)) ?? <String>[];
    return raw
        .map((s) => Bookmark.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> addBookmark(String bookId, Bookmark b) async {
    final list = await getBookmarks(bookId);
    list.add(b);
    final enc = list.map((b) => jsonEncode(b.toJson())).toList();
    await _prefs.setStringList(_key(bookId), enc);
  }

  Future<void> removeAt(String bookId, int index) async {
    final list = await getBookmarks(bookId);
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    final enc = list.map((b) => jsonEncode(b.toJson())).toList();
    await _prefs.setStringList(_key(bookId), enc);
  }

  Future<void> clear(String bookId) async {
    await _prefs.remove(_key(bookId));
  }
}

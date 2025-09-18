import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:book_hub/services/storage/shared_prefs_provider.dart';

const _kSavedBooksKey = 'saved_books_v1';

class SavedBooksStore {
  final SharedPreferences _prefs;
  SavedBooksStore(this._prefs);

  Set<String> getAll() {
    final s = _prefs.getString(_kSavedBooksKey);
    if (s == null) return <String>{};
    final list = (json.decode(s) as List).cast<String>();
    return list.toSet();
  }

  Future<void> _write(Set<String> ids) async {
    await _prefs.setString(_kSavedBooksKey, json.encode(ids.toList()));
  }

  bool isSaved(String bookId) => getAll().contains(bookId);

  Future<void> save(String bookId) async {
    final set = getAll()..add(bookId);
    await _write(set);
  }

  Future<void> unsave(String bookId) async {
    final set = getAll()..remove(bookId);
    await _write(set);
  }

  Future<void> toggle(String bookId) async {
    final set = getAll();
    set.contains(bookId) ? set.remove(bookId) : set.add(bookId);
    await _write(set);
  }

  Future<void> importLegacy(Iterable<String> legacyIds) async {
    final set = getAll()..addAll(legacyIds);
    await _write(set);
  }

  /// NEW: count how many saved books
  Future<int> count() async {
    final s = _prefs.getString(_kSavedBooksKey);
    if (s == null || s.isEmpty) return 0;
    try {
      final list = (json.decode(s) as List).cast<String>();
      return list.length;
    } catch (_) {
      return 0;
    }
  }
}

/// Riverpod
final savedBooksStoreProvider = Provider<SavedBooksStore>((ref) {
  final sp = ref.watch(sharedPrefsProvider);
  return SavedBooksStore(sp);
});

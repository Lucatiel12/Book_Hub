import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedBooksManager {
  static const _prefsKey = 'saved_books';
  static final List<Map<String, dynamic>> _savedBooks = [];
  static bool _loaded = false;

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    _savedBooks
      ..clear()
      ..addAll(raw.map((e) => jsonDecode(e) as Map<String, dynamic>));
    _loaded = true;
  }

  static Future<List<Map<String, dynamic>>> getAll() async {
    await _ensureLoaded();
    return List.unmodifiable(_savedBooks);
  }

  static Future<bool> isBookSaved(String title) async {
    await _ensureLoaded();
    final t = title.trim().toLowerCase();
    return _savedBooks.any(
      (b) => (b['title'] as String?)?.trim().toLowerCase() == t,
    );
  }

  static Future<void> addBook(Map<String, dynamic> book) async {
    await _ensureLoaded();
    final title = (book['title'] as String?) ?? '';
    if (title.isEmpty) return;
    if (await isBookSaved(title)) return;

    _savedBooks.add({
      'title': title,
      'author': book['author'],
      'coverUrl': book['coverUrl'],
      'rating': book['rating'],
      'category': book['category'],
    });
    await _flush();
  }

  static Future<void> removeBookByTitle(String title) async {
    await _ensureLoaded();
    final t = title.trim().toLowerCase();
    _savedBooks.removeWhere(
      (b) => (b['title'] as String?)?.trim().toLowerCase() == t,
    );
    await _flush();
  }

  static Future<void> removeAt(int index) async {
    await _ensureLoaded();
    if (index < 0 || index >= _savedBooks.length) return;
    _savedBooks.removeAt(index);
    await _flush();
  }

  static Future<void> clear() async {
    await _ensureLoaded();
    _savedBooks.clear();
    await _flush();
  }

  static Future<void> _flush() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _savedBooks.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList(_prefsKey, raw);
  }
}

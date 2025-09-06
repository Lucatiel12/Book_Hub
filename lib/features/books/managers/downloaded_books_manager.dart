import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadedBooksManager {
  static const _prefsKey = 'downloaded_books';
  static final List<Map<String, dynamic>> _books = [];
  static bool _loaded = false;

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    _books
      ..clear()
      ..addAll(raw.map((e) => jsonDecode(e) as Map<String, dynamic>));
    _loaded = true;
  }

  static Future<List<Map<String, dynamic>>> getAll() async {
    await _ensureLoaded();
    return List.unmodifiable(_books);
  }

  static Future<bool> isDownloaded(String title) async {
    await _ensureLoaded();
    final t = title.trim().toLowerCase();
    return _books.any(
      (b) => (b['title'] as String?)?.trim().toLowerCase() == t,
    );
  }

  static Future<void> addBook(Map<String, dynamic> book) async {
    await _ensureLoaded();
    final title = (book['title'] as String?) ?? '';
    if (title.isEmpty || await isDownloaded(title)) return;

    _books.add({
      'title': title,
      'author': book['author'],
      'coverUrl': book['coverUrl'],
      'rating': book['rating'],
      'category': book['category'],
      // Later you can store local file paths here (pdfPath/epubPath)
    });
    await _flush();
  }

  static Future<void> removeByTitle(String title) async {
    await _ensureLoaded();
    final t = title.trim().toLowerCase();
    _books.removeWhere(
      (b) => (b['title'] as String?)?.trim().toLowerCase() == t,
    );
    await _flush();
  }

  static Future<void> removeAt(int index) async {
    await _ensureLoaded();
    if (index < 0 || index >= _books.length) return;
    _books.removeAt(index);
    await _flush();
  }

  static Future<void> clear() async {
    await _ensureLoaded();
    _books.clear();
    await _flush();
  }

  static Future<void> _flush() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _books.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList(_prefsKey, raw);
  }
}

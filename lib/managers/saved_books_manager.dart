class SavedBooksManager {
  static final List<Map<String, dynamic>> _savedBooks = [];

  /// ✅ Add this getter so your SavedPage works
  static List<Map<String, dynamic>> get savedBooks =>
      List.unmodifiable(_savedBooks);

  static bool isBookSaved(String title) {
    final t = title.trim().toLowerCase();
    return _savedBooks.any(
      (b) => (b['title'] as String?)?.trim().toLowerCase() == t,
    );
  }

  static void addBook(Map<String, dynamic> book) {
    final title = (book['title'] as String?) ?? '';
    if (title.isEmpty || isBookSaved(title)) return;

    _savedBooks.add({
      'title': title,
      'author': book['author'],
      'coverUrl': book['coverUrl'],
      'rating': book['rating'],
      'category': book['category'],
    });
  }

  static void removeBookByTitle(String title) {
    final t = title.trim().toLowerCase();
    _savedBooks.removeWhere(
      (b) => (b['title'] as String?)?.trim().toLowerCase() == t,
    );
  }

  /// ✅ Remove by index since you're using it in SavedPage
  static void removeBook(int index) {
    if (index >= 0 && index < _savedBooks.length) {
      _savedBooks.removeAt(index);
    }
  }

  static void clear() => _savedBooks.clear();
}

class DownloadedBooksManager {
  static final List<Map<String, dynamic>> _downloadedBooks = [];

  static List<Map<String, dynamic>> get downloadedBooks =>
      List.unmodifiable(_downloadedBooks);

  static bool isBookDownloaded(String title) {
    final t = title.trim().toLowerCase();
    return _downloadedBooks.any(
      (b) => (b['title'] as String?)?.trim().toLowerCase() == t,
    );
  }

  static void addBook(Map<String, dynamic> book) {
    final title = (book['title'] as String?) ?? '';
    if (title.isEmpty || isBookDownloaded(title)) return;

    _downloadedBooks.add({
      'title': title,
      'author': book['author'],
      'coverUrl': book['coverUrl'],
      'rating': book['rating'],
      'category': book['category'],
    });
  }

  static void removeBookByTitle(String title) {
    final t = title.trim().toLowerCase();
    _downloadedBooks.removeWhere(
      (b) => (b['title'] as String?)?.trim().toLowerCase() == t,
    );
  }

  static void clear() => _downloadedBooks.clear();
}

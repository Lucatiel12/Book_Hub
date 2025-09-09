import 'dart:convert';

class HistoryEntry {
  final String bookId;
  final String title;
  final String author;
  final String? coverUrl;

  /// Unix ms
  final int openedAtMillis;

  /// Last known chapter index (0-based)
  final int chapterIndex;

  /// Last known scroll progress in that chapter: 0.0..1.0
  final double scrollProgress;

  const HistoryEntry({
    required this.bookId,
    required this.title,
    required this.author,
    this.coverUrl,
    required this.openedAtMillis,
    required this.chapterIndex,
    required this.scrollProgress,
  });

  HistoryEntry copyWith({
    String? bookId,
    String? title,
    String? author,
    String? coverUrl,
    int? openedAtMillis,
    int? chapterIndex,
    double? scrollProgress,
  }) {
    return HistoryEntry(
      bookId: bookId ?? this.bookId,
      title: title ?? this.title,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      openedAtMillis: openedAtMillis ?? this.openedAtMillis,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      scrollProgress: scrollProgress ?? this.scrollProgress,
    );
  }

  Map<String, dynamic> toMap() => {
    'bookId': bookId,
    'title': title,
    'author': author,
    'coverUrl': coverUrl,
    'openedAtMillis': openedAtMillis,
    'chapterIndex': chapterIndex,
    'scrollProgress': scrollProgress,
  };

  factory HistoryEntry.fromMap(Map<String, dynamic> m) => HistoryEntry(
    bookId: m['bookId'] as String,
    title: m['title'] as String,
    author: m['author'] as String,
    coverUrl: m['coverUrl'] as String?,
    openedAtMillis: (m['openedAtMillis'] as num).toInt(),
    chapterIndex: (m['chapterIndex'] as num).toInt(),
    scrollProgress: (m['scrollProgress'] as num).toDouble(),
  );

  static String encodeList(List<HistoryEntry> list) =>
      jsonEncode(list.map((e) => e.toMap()).toList());

  static List<HistoryEntry> decodeList(String raw) {
    final arr = jsonDecode(raw) as List;
    return arr
        .map((e) => HistoryEntry.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}

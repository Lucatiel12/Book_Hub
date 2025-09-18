enum ReaderFormat { epub, pdf }

class ReaderSource {
  final String bookId;
  final String title;
  final String? author;
  final String path; // absolute local file path
  final ReaderFormat format;

  const ReaderSource({
    required this.bookId,
    required this.title,
    this.author,
    required this.path,
    required this.format,
  });
}

/// A unified bookmark. Use epubLocator for EPUB (JSON/CFI),
/// and (pdfPage,pdfOffset) for PDF.
class ReaderBookmark {
  final String bookId;
  final ReaderFormat format;
  final String? epubLocator; // JSON string emitted by vocsy/FolioReader
  final int? pdfPage; // 1-based
  final double? pdfOffset; // 0..1 (optional)
  final String? note;
  final DateTime createdAt;

  ReaderBookmark({
    required this.bookId,
    required this.format,
    this.epubLocator,
    this.pdfPage,
    this.pdfOffset,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'bookId': bookId,
    'format': format.name,
    'epubLocator': epubLocator,
    'pdfPage': pdfPage,
    'pdfOffset': pdfOffset,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
  };

  static ReaderBookmark fromJson(Map<String, dynamic> j) => ReaderBookmark(
    bookId: j['bookId'] as String,
    format: ReaderFormat.values.firstWhere((f) => f.name == j['format']),
    epubLocator: j['epubLocator'] as String?,
    pdfPage: j['pdfPage'] as int?,
    pdfOffset: (j['pdfOffset'] as num?)?.toDouble(),
    note: j['note'] as String?,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}

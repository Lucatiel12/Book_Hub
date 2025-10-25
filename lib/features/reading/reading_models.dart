// lib/features/reading/reading_models.dart

/// ---- Reading Progress ----
class ReadingProgressDto {
  /// 'pdf' | 'epub' (optional on server)
  final String? format;

  /// Arbitrary position data: e.g. { "page": 12 } for pdf or { "cfi": "...", "chapter": 3 } for epub.
  final Map<String, dynamic>? locator;

  /// May be 0..1 (preferred) or 0..100 (some servers). Use [normalizedPercent] for a guaranteed 0..1.
  final double percent;

  final DateTime? updatedAt;

  ReadingProgressDto({
    this.format,
    this.locator,
    required this.percent,
    this.updatedAt,
  });

  /// Always returns 0..1
  double get normalizedPercent {
    if (percent > 1.0) return (percent / 100.0).clamp(0.0, 1.0);
    if (percent < 0.0) return 0.0;
    return percent;
  }

  factory ReadingProgressDto.fromJson(Map<String, dynamic> j) {
    // backend may use "location" (Swagger) or "locator"
    final rawLocator = (j['location'] ?? j['locator']);
    final mapLocator =
        rawLocator is Map ? rawLocator.cast<String, dynamic>() : null;

    final rawPercent = (j['percent'] as num?)?.toDouble() ?? 0.0;

    return ReadingProgressDto(
      format: j['format'] as String?,
      locator: mapLocator,
      percent: rawPercent,
      updatedAt: _parseIso(j['updatedAt']),
    );
  }

  /// For sending back to the server: server expects "location" key.
  Map<String, dynamic> toJson({bool sendUpdatedAt = false}) {
    final m = <String, dynamic>{
      if (format != null) 'format': format,
      if (locator != null) 'location': locator, // <— important
      'percent': normalizedPercent,
    };
    if (sendUpdatedAt && updatedAt != null) {
      m['updatedAt'] = updatedAt!.toUtc().toIso8601String();
    }
    return m;
  }

  ReadingProgressDto copyWith({
    String? format,
    Map<String, dynamic>? locator,
    double? percent,
    DateTime? updatedAt,
  }) {
    return ReadingProgressDto(
      format: format ?? this.format,
      locator: locator ?? this.locator,
      percent: percent ?? this.percent,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// ---- Reading History (list item) ----
class ReadingHistoryItem {
  final String bookId;
  final String title;
  final String? coverImage; // tolerant
  final DateTime? lastOpenedAt; // tolerant

  ReadingHistoryItem({
    required this.bookId,
    required this.title,
    this.coverImage,
    this.lastOpenedAt,
  });

  factory ReadingHistoryItem.fromJson(Map<String, dynamic> j) {
    return ReadingHistoryItem(
      bookId: j['bookId']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      coverImage: j['coverImage']?.toString(),
      lastOpenedAt: _parseIso(j['lastOpenedAt']),
    );
  }
}

/// ---- Generic paged response (matches `data` of your API) ----
class PageResponse<T> {
  final int totalElements;
  final int totalPages;
  final int size;
  final int number;
  final int numberOfElements;
  final bool last;
  final bool first;
  final bool empty;
  final List<T> content;

  PageResponse({
    required this.totalElements,
    required this.totalPages,
    required this.size,
    required this.number,
    required this.numberOfElements,
    required this.last,
    required this.first,
    required this.empty,
    required this.content,
  });

  static PageResponse<T> fromJson<T>(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final contentJson =
        (j['content'] as List? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>();

    return PageResponse<T>(
      totalElements: (j['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (j['totalPages'] as num?)?.toInt() ?? 0,
      size: (j['size'] as num?)?.toInt() ?? 0,
      number: (j['number'] as num?)?.toInt() ?? 0,
      numberOfElements: (j['numberOfElements'] as num?)?.toInt() ?? 0,
      last: j['last'] as bool? ?? true,
      first: j['first'] as bool? ?? (j['number'] == 0),
      empty: j['empty'] as bool? ?? contentJson.isEmpty,
      content: contentJson.map(itemFromJson).toList(growable: false),
    );
  }
}

/// ---- helpers ----
DateTime? _parseIso(dynamic v) {
  if (v == null) return null;
  try {
    return DateTime.parse(v.toString());
  } catch (_) {
    return null;
  }
}

// lib/backend/models/dtos.dart

// ignore_for_file: constant_identifier_names

// ---- Resource ----
enum ResourceType { IMAGE, EBOOK, DOCUMENT }

ResourceType _parseResourceType(dynamic raw) {
  final s = (raw ?? '').toString().toLowerCase().trim();
  switch (s) {
    case 'ebook':
    case 'epub':
    case 'book':
      return ResourceType.EBOOK;
    case 'document':
    case 'pdf':
    case 'doc':
    case 'docx':
      return ResourceType.DOCUMENT;
    case 'image':
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'webp':
      return ResourceType.IMAGE;
    default:
      return ResourceType.DOCUMENT;
  }
}

ResourceType _inferTypeFromUrl(String url, {String? contentType}) {
  final u = url.toLowerCase();
  final ct = (contentType ?? '').toLowerCase();
  if (u.endsWith('.epub') || ct.contains('epub')) return ResourceType.EBOOK;
  if (u.endsWith('.pdf') || ct.contains('pdf')) return ResourceType.DOCUMENT;
  if (u.endsWith('.jpg') ||
      u.endsWith('.jpeg') ||
      u.endsWith('.png') ||
      u.endsWith('.webp') ||
      ct.startsWith('image/')) {
    return ResourceType.IMAGE;
  }
  return ResourceType.DOCUMENT;
}

class ResourceDto {
  final ResourceType type;
  final String contentUrl;
  final int? sizeBytes;
  final String? originalName;
  final String? checksumSha256;
  final String? contentType;
  final bool? drmProtected;
  final String? uploadedAt;

  ResourceDto({
    required this.type,
    required this.contentUrl,
    this.sizeBytes,
    this.originalName,
    this.checksumSha256,
    this.contentType,
    this.drmProtected,
    this.uploadedAt,
  });

  factory ResourceDto.fromJson(Map<String, dynamic> j) => ResourceDto(
    type: _parseResourceType(j['type']),
    contentUrl:
        (j['contentUrl'] as String?) ??
        (j['url'] as String?) ??
        (j['downloadUrl'] as String?) ??
        '',
    sizeBytes:
        j['sizeBytes'] is int
            ? j['sizeBytes'] as int
            : (j['sizeBytes'] as num?)?.toInt(),
    originalName: j['originalName']?.toString(),
    checksumSha256: j['checksumSha256']?.toString(),
    contentType: j['contentType']?.toString(),
    drmProtected: j['drmProtected'] as bool?,
    uploadedAt: j['uploadedAt']?.toString(),
  );

  /// Build from a plain URL string
  factory ResourceDto.fromUrlString(String url, {String? contentType}) =>
      ResourceDto(
        type: _inferTypeFromUrl(url, contentType: contentType),
        contentUrl: url,
        contentType: contentType,
      );
}

// ---- Book ----
class BookResponseDto {
  final String id;
  final String title;
  final String author;
  final String? description;

  /// Always exposed to UI as `bookFiles`, regardless of backend field name/shape.
  final List<ResourceDto> bookFiles;
  final String? coverImage;
  final List<String> categoryIds;
  final String? isbn;
  final String? publishedDate;
  final List<String> relatedBooks;

  BookResponseDto({
    required this.id,
    required this.title,
    required this.author,
    this.description,
    required this.bookFiles,
    this.coverImage,
    required this.categoryIds,
    this.isbn,
    this.publishedDate,
    required this.relatedBooks,
  });

  static List<ResourceDto> _coerceResources(dynamic raw) {
    if (raw == null) return const <ResourceDto>[];

    // list of objects
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return raw
          .whereType<Map>()
          .map((e) => ResourceDto.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);
    }

    // list of strings
    if (raw is List && raw.isNotEmpty && raw.first is! Map) {
      return raw
          .map((e) => e?.toString())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .map((s) => ResourceDto.fromUrlString(s))
          .toList(growable: false);
    }

    // single object
    if (raw is Map) {
      return [ResourceDto.fromJson(raw.cast<String, dynamic>())];
    }

    // single string
    if (raw is String && raw.isNotEmpty) {
      return [ResourceDto.fromUrlString(raw)];
    }

    return const <ResourceDto>[];
  }

  factory BookResponseDto.fromJson(Map<String, dynamic> j) {
    final rawFiles =
        j['bookFileUrl'] ??
        j['bookFileUrls'] ??
        j['bookFiles'] ??
        j['files'] ??
        j['resources'] ??
        j['bookFileDtos'] ??
        j['bookFile'] ??
        j['fileUrl'];

    final files = _coerceResources(rawFiles);

    return BookResponseDto(
      id: j['id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      author: j['author']?.toString() ?? '',
      description: j['description']?.toString(),
      bookFiles: files,
      coverImage:
          (j['coverImage'] as String?) ??
          (j['coverUrl'] as String?) ??
          (j['imageUrl'] as String?),
      categoryIds: (j['categoryIds'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      isbn: j['isbn']?.toString(),
      publishedDate: j['publishedDate']?.toString(),
      relatedBooks: (j['relatedBooks'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
    );
  }
}

// ---- Paged Books ----
class PageBookResponseDto {
  final int totalElements;
  final int totalPages;
  final int size;
  final int number;
  final List<BookResponseDto> content;

  PageBookResponseDto({
    required this.totalElements,
    required this.totalPages,
    required this.size,
    required this.number,
    required this.content,
  });

  factory PageBookResponseDto.fromJson(Map<String, dynamic> j) =>
      PageBookResponseDto(
        totalElements: (j['totalElements'] as num?)?.toInt() ?? 0,
        totalPages: (j['totalPages'] as num?)?.toInt() ?? 0,
        size: (j['size'] as num?)?.toInt() ?? 0,
        number: (j['number'] as num?)?.toInt() ?? 0,
        content: (j['content'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => BookResponseDto.fromJson(e.cast<String, dynamic>()))
            .toList(growable: false),
      );
}

// ---- Category ----
class CategoryDto {
  final String id;
  final String name;
  final int? bookCount;
  CategoryDto({required this.id, required this.name, this.bookCount});
  factory CategoryDto.fromJson(Map<String, dynamic> j) => CategoryDto(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? '',
    bookCount: (j['bookCount'] as num?)?.toInt(),
  );
}

// ---- User ----
enum UserRole { USER, ADMIN }

UserRole roleFrom(String? v) => (v == 'ADMIN') ? UserRole.ADMIN : UserRole.USER;

class UserAccountDto {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final UserRole role;
  final String? fullName;
  UserAccountDto({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.fullName,
  });
  factory UserAccountDto.fromJson(Map<String, dynamic> j) => UserAccountDto(
    id: j['id']?.toString() ?? '',
    firstName: j['firstName']?.toString() ?? '',
    lastName: j['lastName']?.toString() ?? '',
    email: j['email']?.toString() ?? '',
    role: roleFrom(j['role']?.toString()),
    fullName: j['fullName']?.toString(),
  );
}

// ---- Envelope helper (optional) ----
T? dataField<T>(dynamic root, T Function(Map<String, dynamic>) fromJson) {
  if (root is Map<String, dynamic>) {
    final d = root['data'];
    if (d is Map<String, dynamic>) return fromJson(d);
  }
  return null;
}

// ---- Reading Progress ----
class ReadingProgressDto {
  final String? format;
  final Map<String, dynamic>? locator; // RENAMED: was location
  final double percent;
  final String? updatedAt;

  ReadingProgressDto({
    this.format,
    this.locator, // RENAMED: was location
    required this.percent,
    this.updatedAt,
  });

  factory ReadingProgressDto.fromJson(Map<String, dynamic> j) =>
      ReadingProgressDto(
        format: j['format']?.toString(),
        // accept either key to be backward-compatible
        locator:
            (j['locator'] is Map<String, dynamic>)
                ? (j['locator'] as Map<String, dynamic>)
                : (j['location'] is Map<String, dynamic>)
                ? (j['location'] as Map<String, dynamic>)
                : null,
        percent: (j['percent'] as num?)?.toDouble() ?? 0.0,
        updatedAt: j['updatedAt']?.toString(),
      );

  Map<String, dynamic> toJson() => {
    if (format != null) 'format': format,
    if (locator != null) 'locator': locator, // Send the new key 'locator'
    'percent': percent,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };
}

// ---- Reading History ----
class ReadingHistoryItemDto {
  final String bookId;
  final String title;
  final String? coverImage;
  final String? lastOpenedAt;

  ReadingHistoryItemDto({
    required this.bookId,
    required this.title,
    this.coverImage,
    this.lastOpenedAt,
  });

  factory ReadingHistoryItemDto.fromJson(Map<String, dynamic> j) =>
      ReadingHistoryItemDto(
        bookId: j['bookId']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        coverImage: j['coverImage']?.toString(),
        lastOpenedAt: j['lastOpenedAt']?.toString(),
      );
}

class PageReadingHistoryResponseDto {
  final int totalElements;
  final int totalPages;
  final int size;
  final int number;
  final List<ReadingHistoryItemDto> content;

  PageReadingHistoryResponseDto({
    required this.totalElements,
    required this.totalPages,
    required this.size,
    required this.number,
    required this.content,
  });

  factory PageReadingHistoryResponseDto.fromJson(Map<String, dynamic> j) =>
      PageReadingHistoryResponseDto(
        totalElements: (j['totalElements'] as num?)?.toInt() ?? 0,
        totalPages: (j['totalPages'] as num?)?.toInt() ?? 0,
        size: (j['size'] as num?)?.toInt() ?? 0,
        number: (j['number'] as num?)?.toInt() ?? 0,
        content: (j['content'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (e) => ReadingHistoryItemDto.fromJson(e.cast<String, dynamic>()),
            )
            .toList(growable: false),
      );
}

// Minimal DTOs that match your Swagger exactly (no codegen needed).

enum ResourceType { IMAGE, EBOOK, DOCUMENT }

ResourceType _resourceTypeFrom(String? v) {
  switch (v) {
    case 'IMAGE':
      return ResourceType.IMAGE;
    case 'EBOOK':
      return ResourceType.EBOOK;
    case 'DOCUMENT':
      return ResourceType.DOCUMENT;
    default:
      return ResourceType.DOCUMENT;
  }
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
    type: _resourceTypeFrom(j['type']?.toString()),
    contentUrl: j['contentUrl']?.toString() ?? '',
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
}

class BookResponseDto {
  final String id;
  final String title;
  final String author;
  final String? description;
  final List<ResourceDto> bookFiles; // EBOOK/PDF(s)
  final String? coverImage; // Cloudinary URL (string)
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

  factory BookResponseDto.fromJson(Map<String, dynamic> j) => BookResponseDto(
    id: j['id']?.toString() ?? '',
    title: j['title']?.toString() ?? '',
    author: j['author']?.toString() ?? '',
    description: j['description']?.toString(),
    bookFiles: (j['bookFiles'] as List<dynamic>? ?? const [])
        .map((e) => ResourceDto.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
    coverImage: j['coverImage']?.toString(),
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

class PageBookResponseDto {
  final int totalElements;
  final int totalPages;
  final int size;
  final int number; // pageNumber
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
            .map((e) => BookResponseDto.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

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

/// Envelope helpers (your API wraps everything in { data, error })
T? dataField<T>(dynamic root, T Function(Map<String, dynamic>) fromJson) {
  if (root is Map<String, dynamic>) {
    final d = root['data'];
    if (d is Map<String, dynamic>) return fromJson(d);
  }
  return null;
}

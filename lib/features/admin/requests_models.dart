// lib/features/admin/requests_models.dart

/// Matches Swagger enums:
/// requestType: "CONTRIBUTION" | "LOOKUP"
/// status: "PENDING" | "APPROVED" | "REJECTED"
enum BookRequestType { CONTRIBUTION, LOOKUP }

enum BookRequestStatus { PENDING, APPROVED, REJECTED }

BookRequestType _typeFrom(String? v) {
  switch (v) {
    case 'LOOKUP':
      return BookRequestType.LOOKUP;
    case 'CONTRIBUTION':
    default:
      return BookRequestType.CONTRIBUTION;
  }
}

BookRequestStatus _statusFrom(String? v) {
  switch (v) {
    case 'APPROVED':
      return BookRequestStatus.APPROVED;
    case 'REJECTED':
      return BookRequestStatus.REJECTED;
    case 'PENDING':
    default:
      return BookRequestStatus.PENDING;
  }
}

/// ------------------------------
/// NEW: request DTOs (from Swagger)
/// ------------------------------

/// POST /api/v1/requests/lookup
/// Swagger: BookLookupRequestDTO
class BookLookupRequestDto {
  final String title; // ≥ 1 character
  final String? author;
  final String? description;
  final String? isbn;

  BookLookupRequestDto({
    required this.title,
    this.author,
    this.description,
    this.isbn,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    if (author != null && author!.isNotEmpty) 'author': author,
    if (description != null && description!.isNotEmpty)
      'description': description,
    if (isbn != null && isbn!.isNotEmpty) 'isbn': isbn,
  };
}

/// POST /api/v1/requests/contribute
/// Swagger: BookContributionRequestDTO
/// (We’re only sending the JSON fields for now. If you later upload files,
/// switch to multipart.)
class BookContributionRequestDto {
  final String title; // ≥ 1 character
  final String author; // ≥ 1 character
  final String? description;
  final List<String>? categoryIds;
  final String? isbn;

  // (bookFile[], coverImage omitted for now – add multipart later)

  BookContributionRequestDto({
    required this.title,
    required this.author,
    this.description,
    this.categoryIds,
    this.isbn,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'author': author,
    if (description != null && description!.isNotEmpty)
      'description': description,
    if (categoryIds != null && categoryIds!.isNotEmpty)
      'categoryIds': categoryIds,
    if (isbn != null && isbn!.isNotEmpty) 'isbn': isbn,
  };
}

/// One admin request row (Swagger: BookRequestResponseDTO)
class BookRequestResponseDto {
  final String? id;
  final BookRequestType requestType;
  final BookRequestStatus status;
  final String? title;
  final String? author;
  final String? description;
  final String? isbn;
  final List<String> categoryIds;
  final String? userId;
  final String? createdAt; // ISO string
  final String? updatedAt; // ISO string
  final String? rejectionReason;
  final String? createdBookId;

  BookRequestResponseDto({
    required this.id,
    required this.requestType,
    required this.status,
    required this.title,
    required this.author,
    required this.description,
    required this.isbn,
    required this.categoryIds,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    required this.rejectionReason,
    required this.createdBookId,
  });

  factory BookRequestResponseDto.fromJson(Map<String, dynamic> j) {
    return BookRequestResponseDto(
      id: j['id']?.toString(),
      requestType: _typeFrom(j['requestType']?.toString()),
      status: _statusFrom(j['status']?.toString()),
      title: j['title']?.toString(),
      author: j['author']?.toString(),
      description: j['description']?.toString(),
      isbn: j['isbn']?.toString(),
      categoryIds: (j['categoryIds'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      userId: j['userId']?.toString(),
      createdAt: j['createdAt']?.toString(),
      updatedAt: j['updatedAt']?.toString(),
      rejectionReason: j['rejectionReason']?.toString(),
      createdBookId: j['createdBookId']?.toString(),
    );
  }
}

/// Paged wrapper (Swagger: PageBookRequestResponseDTO)
class PageBookRequestResponseDto {
  final int totalElements;
  final int totalPages;
  final int size;
  final int number;
  final bool first;
  final bool last;
  final bool empty;
  final List<BookRequestResponseDto> content;

  PageBookRequestResponseDto({
    required this.totalElements,
    required this.totalPages,
    required this.size,
    required this.number,
    required this.first,
    required this.last,
    required this.empty,
    required this.content,
  });

  factory PageBookRequestResponseDto.fromJson(Map<String, dynamic> j) {
    return PageBookRequestResponseDto(
      totalElements: (j['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (j['totalPages'] as num?)?.toInt() ?? 0,
      size: (j['size'] as num?)?.toInt() ?? 0,
      number: (j['number'] as num?)?.toInt() ?? 0,
      first: j['first'] as bool? ?? false,
      last: j['last'] as bool? ?? false,
      empty: j['empty'] as bool? ?? false,
      content: (j['content'] as List<dynamic>? ?? const [])
          .map(
            (e) => BookRequestResponseDto.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }
}

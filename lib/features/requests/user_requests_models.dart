// lib/features/requests/user_requests_models.dart

/// JSON body for POST /api/v1/requests/lookup
class BookLookupRequestDto {
  final String title; // required by Swagger (≥ 1 char)
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

/// JSON body for POST /api/v1/requests/contribute
/// (pure JSON version; user is expected to paste a link in description or a field)
class BookContributionRequestDto {
  final String title; // required (≥ 1 char)
  final String author; // required (≥ 1 char)
  final String? description; // include drive link here if you want
  final List<String>? categoryIds;
  final String? isbn;

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

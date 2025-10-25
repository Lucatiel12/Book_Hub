// lib/backend/book_repository.dart
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'models/dtos.dart';
import 'api_client.dart';
import 'package:http_parser/http_parser.dart';

// Simple page wrapper used by UI
class PageResult<T> {
  final List<T> items;
  final int pageNumber;
  final int totalPages;
  const PageResult({
    required this.items,
    required this.pageNumber,
    required this.totalPages,
  });
}

// Your UI model used across the app
class UiBook {
  final String id;
  final String title;
  final String author;
  final String description;
  final String? coverUrl;
  final String? ebookUrl;
  final List<String> categoryIds;
  final List<ResourceDto> resources;

  const UiBook({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    this.coverUrl,
    this.ebookUrl,
    required this.categoryIds,
    required this.resources,
  });

  // 4) UPDATED: Make UiBook.fromDto even more forgiving
  factory UiBook.fromDto(BookResponseDto d) {
    String? ebookUrl;

    // prefer explicit EBOOK/DOCUMENT
    for (final r in d.bookFiles) {
      if (r.type == ResourceType.EBOOK || r.type == ResourceType.DOCUMENT) {
        ebookUrl = r.contentUrl;
        break;
      }
    }
    // fallback: any resource
    ebookUrl ??= d.bookFiles.isNotEmpty ? d.bookFiles.first.contentUrl : null;

    return UiBook(
      id: d.id,
      title: d.title,
      author: d.author,
      description: d.description ?? '',
      coverUrl: d.coverImage,
      ebookUrl: ebookUrl,
      categoryIds: d.categoryIds,
      resources: d.bookFiles,
    );
  }
}

class BookRepository {
  final ApiClient _api;
  BookRepository(this._api);

  /// Fetches a paginated list of books, forwards to ApiClient.getBooks and maps to UiBook.
  Future<PageResult<UiBook>> getBooks({
    String? query,
    String? categoryId,
    int page = 0,
    int size = 20,
  }) async {
    final dtoPage = await _api.getBooks(
      query: query,
      categoryId: categoryId,
      page: page,
      size: size,
    );
    final items = dtoPage.content.map(UiBook.fromDto).toList();
    return PageResult(
      items: items,
      pageNumber: dtoPage.number,
      totalPages: dtoPage.totalPages,
    );
  }

  /// GET /api/v1/books/search
  /// Backend expects `title` as the query parameter. We expose it as `query`
  /// and map it to `title`. `number` is the current page index in the payload.
  Future<PageResult<UiBook>> search({
    String? query,
    String? categoryId,
    int page = 0,
    int size = 20,
  }) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/books/search',
      queryParameters: {
        if (query != null && query.isNotEmpty) 'title': query,
        if (categoryId != null && categoryId.isNotEmpty)
          'categoryId': categoryId,
        'page': page,
        'size': size,
      },
    );

    final root = res.data ?? const <String, dynamic>{};
    final data = (root['data'] ?? root) as Map<String, dynamic>;

    final contentList = (data['content'] as List<dynamic>? ?? const []);
    final items =
        contentList
            .map(
              (e) => UiBook.fromDto(
                BookResponseDto.fromJson(e as Map<String, dynamic>),
              ),
            )
            .toList();

    final totalPages = (data['totalPages'] as int?) ?? 1;
    final pageNumber = (data['number'] as int?) ?? 0; // <-- from Swagger

    return PageResult<UiBook>(
      items: items,
      pageNumber: pageNumber,
      totalPages: totalPages,
    );
  }

  // 2) UPDATED: Use the raw payload and keep logging
  Future<UiBook> getById(String id) async {
    // Swap to raw so we can inspect fields
    final raw = await _api.getBookRaw(id);

    // TEMP DEBUG — this prints once when you open BookDetails
    // so we can see EXACTLY what the backend returns.
    // Please leave these until we confirm shape.
    // You should see these in your debug console.
    // ----------------------------------------------------
    // Useful keys & their types
    // ----------------------------------------------------
    // ignore: avoid_print
    print('BOOK RAW KEYS: ${raw.keys.toList()}');
    // ignore: avoid_print
    print(
      'bookFileUrl -> ${raw['bookFileUrl']?.runtimeType} = ${raw['bookFileUrl']}',
    );
    // ignore: avoid_print
    print(
      'bookFiles   -> ${raw['bookFiles']?.runtimeType}   = ${raw['bookFiles']}',
    );
    // ignore: avoid_print
    print(
      'fileUrl     -> ${raw['fileUrl']?.runtimeType}     = ${raw['fileUrl']}',
    );
    // ignore: avoid_print
    print(
      'files       -> ${raw['files']?.runtimeType}       = ${raw['files']}',
    );
    // ignore: avoid_print
    print(
      'resources   -> ${raw['resources']?.runtimeType}   = ${raw['resources']}',
    );

    final dto = BookResponseDto.fromJson(raw);
    return UiBook.fromDto(dto);
  }

  // 3) REPLACED: Belt-and-suspenders fallback for resolveDownloadUri
  Future<Uri?> resolveDownloadUri(String id) async {
    // 1) Use the parsed DTO first
    final raw = await _api.getBookRaw(id);
    final dto = BookResponseDto.fromJson(raw);

    // from parsed resources
    for (final r in dto.bookFiles) {
      final u = r.contentUrl.trim();
      if (u.isNotEmpty) return Uri.tryParse(u);
    }

    // from legacy top-level fields we might have missed
    final candidates = <String?>[
      dto.coverImage, // unlikely, but sometimes misused
      raw['downloadUrl']?.toString(),
      raw['fileUrl']?.toString(),
      raw['bookFileUrl']?.toString(), // single string case
    ];

    // if any of the above are arrays, pull their first item
    for (final k in ['bookFileUrl', 'bookFiles', 'files', 'resources']) {
      final v = raw[k];
      if (v is List && v.isNotEmpty) {
        final first = v.first;
        if (first is String) candidates.add(first);
        if (first is Map && first['contentUrl'] != null) {
          candidates.add(first['contentUrl'].toString());
        }
        break;
      }
    }

    for (final s in candidates) {
      final url = (s ?? '').trim();
      if (url.isNotEmpty) return Uri.tryParse(url);
    }

    return null;
  }

  Future<List<CategoryDto>> categories() async {
    final list = await _api.getCategories();
    return list;
  }
}

extension AdminBooks on BookRepository {
  Future<BookResponseDto> adminCreateBook({
    required String title,
    required String author,
    String? description,
    String? isbn,
    String? publishedDate,
    required List<String> categoryIds,
    String? coverPath,
    required String ebookPath,
  }) async {
    // pick a content type the backend will recognize
    String _guessContentType(String path) {
      final lower = path.toLowerCase();
      if (lower.endsWith('.epub')) return 'application/epub+zip';
      if (lower.endsWith('.pdf')) return 'application/pdf';
      return 'application/octet-stream';
    }

    final ebookCt = _guessContentType(ebookPath);

    // Build multipart form
    final form = FormData();

    form.fields
      ..add(MapEntry('title', title))
      ..add(MapEntry('author', author));

    if (description != null && description.isNotEmpty) {
      form.fields.add(MapEntry('description', description));
    }
    if (isbn != null && isbn.isNotEmpty) {
      form.fields.add(MapEntry('isbn', isbn));
    }
    if (publishedDate != null && publishedDate.isNotEmpty) {
      form.fields.add(MapEntry('publishedDate', publishedDate));
    }
    for (final id in categoryIds) {
      // many backends expect repeated field names for arrays
      form.fields.add(MapEntry('categoryIds', id));
    }

    if (coverPath != null && coverPath.isNotEmpty) {
      form.files.add(
        MapEntry(
          'coverImage',
          await MultipartFile.fromFile(
            coverPath,
            filename: p.basename(coverPath),
            contentType: MediaType(
              'image',
              coverPath.toLowerCase().endsWith('.png') ? 'png' : 'jpeg',
            ),
          ),
        ),
      );
    }

    // ---- THE IMPORTANT PART: attach ebook under single key ----
    // a) singular: bookFile
    final ebookFile = await MultipartFile.fromFile(
      ebookPath,
      filename: p.basename(ebookPath),
      contentType: MediaType.parse(ebookCt),
    );

    // ✅ Only this
    form.files.add(MapEntry('bookFile', ebookFile));

    // ❌ Remove these duplicates (they caused the finalize error)
    // form.files.add(MapEntry('bookFiles', ebookFile));
    // form.files.add(MapEntry('files', ebookFile));

    // ---- POST (your ApiClient already prefixes /api/v1) ----
    final res = await _api.post<Map<String, dynamic>>(
      '/books',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );

    // Some servers return the created book, some just an id, some wrap in {data:…}
    final root = res.data ?? const <String, dynamic>{};
    final data =
        (root['data'] is Map<String, dynamic>)
            ? (root['data'] as Map<String, dynamic>)
            : root;

    // If backend returns only an id, immediately fetch the book to confirm file wiring
    final created =
        (data['id'] != null &&
                (data['title'] == null || data['bookFileUrl'] == null))
            ? await _api.getBookRaw(data['id'].toString())
            : data;

    // TEMP: log what the server actually stored
    // ignore: avoid_print
    print(
      'ADMIN CREATE → bookFileUrl: ${created['bookFileUrl']}   files: ${created['bookFiles'] ?? created['files']}',
    );

    return BookResponseDto.fromJson(created);
  }
}

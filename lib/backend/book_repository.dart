// lib/backend/book_repository.dart
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'models/dtos.dart';
import 'api_client.dart';

class UiBook {
  final String id;
  final String title;
  final String author;
  final String? description;
  final String? coverUrl;
  final String? ebookUrl;
  final List<String> categoryIds;
  final List<ResourceDto> resources;

  UiBook({
    required this.id,
    required this.title,
    required this.author,
    this.description,
    this.coverUrl,
    this.ebookUrl,
    required this.categoryIds,
    required this.resources,
  });

  factory UiBook.fromDto(BookResponseDto d) {
    final firstFile = d.bookFiles.firstWhere(
      (r) => r.type == ResourceType.EBOOK || r.type == ResourceType.DOCUMENT,
      orElse: () => ResourceDto(type: ResourceType.DOCUMENT, contentUrl: ''),
    );
    return UiBook(
      id: d.id,
      title: d.title,
      author: d.author,
      description: d.description,
      coverUrl: d.coverImage,
      ebookUrl: firstFile.contentUrl.isEmpty ? null : firstFile.contentUrl,
      categoryIds: d.categoryIds,
      resources: d.bookFiles,
    );
  }
}

class BookRepository {
  final ApiClient _api;
  BookRepository(this._api);

  Future<(List<UiBook> items, int page, int totalPages)> search({
    String? query,
    String? categoryId,
    int page = 0,
    int size = 20,
  }) async {
    final p = await _api.getBooks(
      query: query,
      categoryId: categoryId,
      page: page,
      size: size,
    );
    final mapped = p.content.map(UiBook.fromDto).toList();
    return (mapped, p.number, p.totalPages);
  }

  Future<UiBook> getById(String id) async {
    final d = await _api.getBook(id);
    return UiBook.fromDto(d);
  }

  Future<Uri?> resolveDownloadUri(String id) async {
    final d = await _api.getBook(id);
    final f = d.bookFiles.firstWhere(
      (r) => r.type == ResourceType.EBOOK || r.type == ResourceType.DOCUMENT,
      orElse: () => ResourceDto(type: ResourceType.DOCUMENT, contentUrl: ''),
    );
    if (f.contentUrl.isEmpty) return null;
    return Uri.tryParse(f.contentUrl);
  }

  Future<List<CategoryDto>> categories() async {
    final list = await _api.getCategories();
    return list;
  }
}

extension AdminBooks on BookRepository {
  Future<void> adminCreateBook({
    required String title,
    required String author,
    String? description,
    String? isbn,
    String? publishedDate,
    required List<String> categoryIds,
    String? coverPath,
    required String ebookPath,
  }) async {
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
      form.fields.add(MapEntry('categoryIds', id));
    }

    if (coverPath != null && coverPath.isNotEmpty) {
      form.files.add(
        MapEntry(
          'coverImage',
          await MultipartFile.fromFile(
            coverPath,
            filename: p.basename(coverPath),
          ),
        ),
      );
    }

    form.files.add(
      MapEntry(
        'bookFile',
        await MultipartFile.fromFile(
          ebookPath,
          filename: p.basename(ebookPath),
        ),
      ),
    );

    // ✅ Call the path WITHOUT the /api/v1 prefix
    await _api.post(
      '/books', // Changed from '/api/v1/books'
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
  }
}

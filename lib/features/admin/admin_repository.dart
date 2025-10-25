// lib/features/admin/admin_repository.dart
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart'; // PlatformFile
import 'package:book_hub/backend/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminCreateBookRequest {
  final String title;
  final String author;
  final String? description;
  final String? isbn;
  final String? publishedDate; // send as String per Swagger
  final List<String> categoryIds;
  final List<String> relatedBooks;

  final PlatformFile? coverImage; // matches backend name
  final List<PlatformFile> bookFiles; // array (pdf/epub)

  AdminCreateBookRequest({
    required this.title,
    required this.author,
    this.description,
    this.isbn,
    this.publishedDate,
    required this.categoryIds,
    this.relatedBooks = const [],
    this.coverImage,
    required this.bookFiles,
  });
}

class AdminRepository {
  final ApiClient _api;
  AdminRepository(this._api);

  Future<void> adminCreateBook(
    AdminCreateBookRequest req, {
    ProgressCallback? onSendProgress,
  }) async {
    final form = FormData();

    // scalar fields
    form.fields
      ..add(MapEntry('title', req.title))
      ..add(MapEntry('author', req.author));

    if (req.description?.isNotEmpty == true) {
      form.fields.add(MapEntry('description', req.description!));
    }
    if (req.isbn?.isNotEmpty == true) {
      form.fields.add(MapEntry('isbn', req.isbn!));
    }
    if (req.publishedDate?.isNotEmpty == true) {
      form.fields.add(MapEntry('publishedDate', req.publishedDate!));
    }
    for (final id in req.categoryIds) {
      form.fields.add(MapEntry('categoryIds', id));
    }
    for (final id in req.relatedBooks) {
      form.fields.add(MapEntry('relatedBooks', id));
    }

    // cover (optional)
    if (req.coverImage != null) {
      final f = req.coverImage!;
      final mf =
          (f.bytes != null)
              ? MultipartFile.fromBytes(f.bytes!, filename: f.name)
              : await MultipartFile.fromFile(f.path!, filename: f.name);
      form.files.add(MapEntry('coverImage', mf)); // exact key
    }

    // book files (required >= 1)
    for (final f in req.bookFiles) {
      final mf =
          (f.bytes != null)
              ? MultipartFile.fromBytes(f.bytes!, filename: f.name)
              : await MultipartFile.fromFile(f.path!, filename: f.name);

      // ✅ Send ONLY the expected key
      form.files.add(MapEntry('bookFile', mf));
    }

    await _api.postMultipart<void>(
      '/books', // ApiClient already prefixes /api/v1
      data: form,
      onSendProgress: onSendProgress,
    );
  }

  // NEW
  Future<void> deleteBook(String bookId) async {
    await _api.deleteBook(bookId);
  }
}

// NEW provider
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final api = ref.read(apiClientProvider);
  return AdminRepository(api);
});

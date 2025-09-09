// lib/managers/downloaded_books_manager.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:book_hub/services/storage/downloaded_books_store.dart';

class DownloadedBooksManager {
  final DownloadedBooksStore _store;
  final Dio _dio;

  DownloadedBooksManager(this._store, this._dio);

  Future<bool> isDownloaded(String bookId) => _store.isDownloaded(bookId);
  Future<void> delete(String bookId) => _store.delete(bookId);
  Future<void> touch(String bookId) => _store.touch(bookId);
  Future<List<DownloadEntry>> list() => _store.list();

  /// Existing simple API (kept for compatibility)
  Future<void> downloadFromUrl({
    required String bookId,
    required String url,
    String? ext,
    String? title,
    String? author,
    String? coverUrl,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final resp = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
    );
    final bytes = resp.data ?? <int>[];
    await _store.saveBytes(
      bookId: bookId,
      bytes: bytes,
      ext: ext,
      title: title,
      author: author,
      coverUrl: coverUrl,
    );
  }

  /// ✅ Resumable streaming download with .part temp file + Range support.
  Future<void> downloadResumable({
    required String bookId,
    required String url,
    String ext = 'epub',
    String? title,
    String? author,
    String? coverUrl,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    // compute target/part paths
    final docs = await getApplicationDocumentsDirectory();
    final safeId = bookId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final dir = Directory(p.join(docs.path, 'books'));
    if (!await dir.exists()) await dir.create(recursive: true);

    final finalPath = p.join(dir.path, '$safeId.$ext');
    final partPath = '$finalPath.part';
    final partFile = File(partPath);

    // existing partial
    int existingBytes = 0;
    if (await partFile.exists()) {
      existingBytes = await partFile.length();
    } else {
      // ensure any old finalized file is removed before starting
      final oldFinal = File(finalPath);
      if (await oldFinal.exists()) await oldFinal.delete();
    }

    // prepare headers for resume
    final headers = <String, dynamic>{};
    if (existingBytes > 0) headers['Range'] = 'bytes=$existingBytes-';

    Response<ResponseBody> resp;
    try {
      resp = await _dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          followRedirects: true,
          validateStatus: (c) => c != null && c >= 200 && c < 400,
        ),
        cancelToken: cancelToken,
      );
    } on DioException {
      // handshake failed – keep .part for later resume
      rethrow;
    }

    final isResumed = resp.statusCode == 206;
    if (existingBytes > 0 && !isResumed) {
      // server ignored Range; start fresh to avoid corruption
      if (await partFile.exists()) await partFile.delete();
      existingBytes = 0;
    }

    // length for this leg
    final lenHeader = resp.headers.value(Headers.contentLengthHeader);
    final legLength = int.tryParse(lenHeader ?? '') ?? -1;
    final expectedTotal = legLength > 0 ? existingBytes + legLength : -1;

    // open .part for append
    await partFile.parent.create(recursive: true);
    final raf = await partFile.open(mode: FileMode.append);

    int receivedThisLeg = 0;
    try {
      await for (final chunk in resp.data!.stream) {
        if (cancelToken?.isCancelled == true) {
          // leave .part in place – treated as paused/canceled by caller
          return;
        }
        await raf.writeFrom(chunk);
        receivedThisLeg += chunk.length;
        if (onProgress != null && expectedTotal > 0) {
          onProgress(existingBytes + receivedThisLeg, expectedTotal);
        }
      }
    } finally {
      await raf.close();
    }

    // success: rename .part → final
    final finalFile = File(finalPath);
    if (await finalFile.exists()) await finalFile.delete();
    await partFile.rename(finalPath);

    // index without re-reading bytes
    await _store.saveFromExistingFile(
      bookId: bookId,
      absolutePath: finalPath,
      title: title,
      author: author,
      coverUrl: coverUrl,
    );
  }
}

/// Riverpod providers (if not already defined elsewhere)
final dioProvider = Provider<Dio>((ref) => Dio());

final downloadedBooksManagerProvider = Provider<DownloadedBooksManager>((ref) {
  final store = ref.watch(downloadedBooksStoreProvider);
  final dio = ref.watch(dioProvider);
  return DownloadedBooksManager(store, dio);
});

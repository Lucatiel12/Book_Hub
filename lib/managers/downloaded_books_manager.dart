import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:book_hub/backend/api_client.dart';
import 'package:book_hub/services/storage/downloaded_books_store.dart';
import 'package:book_hub/features/books/providers/saved_downloaded_providers.dart';
import 'package:book_hub/features/profile/profile_stats_provider.dart';

class DownloadedBooksManager {
  DownloadedBooksManager(this.ref, this._store, this._dio);

  final Ref ref;
  final DownloadedBooksStore _store;
  final Dio _dio;

  Future<bool> isDownloaded(String bookId) => _store.isDownloaded(bookId);
  Future<void> touch(String bookId) => _store.touch(bookId);
  Future<List<DownloadEntry>> list() => _store.list();

  Future<void> delete(String bookId) async {
    final entry = await _store.getByBookId(bookId);

    if (entry != null && entry.path.isNotEmpty) {
      try {
        final f = File(entry.path);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {
        /* ignore */
      }
    }

    await _store.delete(bookId);

    // Keep per-book & stats in sync (do NOT invalidate the list here)
    ref.invalidate(isBookDownloadedProvider(bookId));
    ref.invalidate(profileStatsProvider);
  }

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

    ref.invalidate(isBookDownloadedProvider(bookId));
    ref.invalidate(profileStatsProvider);
  }

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
    final docs = await getApplicationDocumentsDirectory();
    final safeId = bookId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final dir = Directory(p.join(docs.path, 'books'));
    if (!await dir.exists()) await dir.create(recursive: true);

    final finalPath = p.join(dir.path, '$safeId.$ext');
    final partPath = '$finalPath.part';
    final partFile = File(partPath);

    int existingBytes = 0;
    if (await partFile.exists()) {
      existingBytes = await partFile.length();
    } else {
      final oldFinal = File(finalPath);
      if (await oldFinal.exists()) await oldFinal.delete();
    }

    final headers = <String, dynamic>{};
    if (existingBytes > 0) headers['Range'] = 'bytes=$existingBytes-';

    final resp = await _dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: headers,
        followRedirects: true,
        validateStatus: (c) => c != null && c >= 200 && c < 400,
      ),
      cancelToken: cancelToken,
    );

    final isResumed = resp.statusCode == 206;
    if (existingBytes > 0 && !isResumed) {
      if (await partFile.exists()) await partFile.delete();
      existingBytes = 0;
    }

    final lenHeader = resp.headers.value(Headers.contentLengthHeader);
    final legLength = int.tryParse(lenHeader ?? '') ?? -1;
    final expectedTotal = legLength > 0 ? existingBytes + legLength : -1;

    await partFile.parent.create(recursive: true);
    final raf = await partFile.open(mode: FileMode.append);

    int receivedThisLeg = 0;
    try {
      await for (final chunk in resp.data!.stream) {
        if (cancelToken?.isCancelled == true) return;
        await raf.writeFrom(chunk);
        receivedThisLeg += chunk.length;
        if (onProgress != null && expectedTotal > 0) {
          onProgress(existingBytes + receivedThisLeg, expectedTotal);
        }
      }
    } finally {
      await raf.close();
    }

    final finalFile = File(finalPath);
    if (await finalFile.exists()) await finalFile.delete();
    await partFile.rename(finalPath);

    await _store.saveFromExistingFile(
      bookId: bookId,
      absolutePath: finalPath,
      title: title,
      author: author,
      coverUrl: coverUrl,
    );

    ref.invalidate(isBookDownloadedProvider(bookId));
    ref.invalidate(profileStatsProvider);
  }

  Future<DownloadEntry> importLocalFile({
    required String sourcePath,
    String? title,
    String? author,
    String? coverUrl,
  }) async {
    final f = File(sourcePath);
    if (!await f.exists()) {
      throw Exception('File does not exist');
    }

    final lower = sourcePath.toLowerCase();
    late final String ext;
    if (lower.endsWith('.pdf')) {
      ext = 'pdf';
    } else if (lower.endsWith('.epub')) {
      ext = 'epub';
    } else {
      throw Exception('Unsupported file type');
    }

    // ignore: no_leading_underscores_for_local_identifiers
    String _localIdFor(String path) =>
        'local:${base64Url.encode(utf8.encode(path))}';
    final bookId = _localIdFor(sourcePath);

    title ??= p.basenameWithoutExtension(sourcePath);
    author ??= '-';

    final destPath = await _store.targetPath(bookId, ext: ext);
    await f.copy(destPath);

    final entry = await _store.saveFromExistingFile(
      bookId: bookId,
      absolutePath: destPath,
      title: title,
      author: author,
      coverUrl: coverUrl,
    );

    ref.invalidate(isBookDownloadedProvider(bookId));
    ref.invalidate(profileStatsProvider);

    return entry;
  }
}

//---

extension TempFastRead on DownloadedBooksManager {
  /// Downloads to a **CACHE temp file** (not indexed; not shown in Library).
  /// Returns the absolute path. Supports resume via `.part`.
  Future<String> downloadToTemp({
    required String bookId,
    required String url,
    String ext = 'epub',
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final docs = await getTemporaryDirectory(); // cache, not persisted
    final safeId = bookId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final dir = Directory(p.join(docs.path, 'bookhub_cache'));
    if (!await dir.exists()) await dir.create(recursive: true);

    final finalPath = p.join(dir.path, '$safeId.$ext');
    final partPath = '$finalPath.part';
    final partFile = File(partPath);
    final finalFile = File(finalPath);

    int existingBytes = 0;
    if (await partFile.exists()) {
      existingBytes = await partFile.length();
    } else {
      if (await finalFile.exists()) await finalFile.delete();
    }

    final headers = <String, dynamic>{};
    if (existingBytes > 0) headers['Range'] = 'bytes=$existingBytes-';

    final resp = await _dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: headers,
        followRedirects: true,
        validateStatus: (c) => c != null && c >= 200 && c < 400,
      ),
      cancelToken: cancelToken,
    );

    final isResumed = resp.statusCode == 206;
    if (existingBytes > 0 && !isResumed) {
      if (await partFile.exists()) await partFile.delete();
      existingBytes = 0;
    }

    final lenHeader = resp.headers.value(Headers.contentLengthHeader);
    final legLength = int.tryParse(lenHeader ?? '') ?? -1;
    final expectedTotal = legLength > 0 ? existingBytes + legLength : -1;

    await partFile.parent.create(recursive: true);
    final raf = await partFile.open(mode: FileMode.append);

    int receivedThisLeg = 0;
    try {
      await for (final chunk in resp.data!.stream) {
        if (cancelToken?.isCancelled == true) return finalPath; // exit early
        await raf.writeFrom(chunk);
        receivedThisLeg += chunk.length;
        if (onProgress != null && expectedTotal > 0) {
          onProgress(existingBytes + receivedThisLeg, expectedTotal);
        }
      }
    } finally {
      await raf.close();
    }

    if (await finalFile.exists()) await finalFile.delete();
    await partFile.rename(finalPath);
    return finalPath; // path to temp file
  }
}

//---

final downloadedBooksManagerProvider = Provider<DownloadedBooksManager>((ref) {
  final store = ref.watch(downloadedBooksStoreProvider);
  final api = ref.watch(apiClientProvider);
  return DownloadedBooksManager(ref, store, api.dio);
});

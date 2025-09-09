// lib/services/storage/downloaded_books_store.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:book_hub/services/storage/shared_prefs_provider.dart';

const _kDownloadsIndexKey = 'downloads_index_v1';

class DownloadEntry {
  final String bookId;
  final String path; // absolute path
  final int bytes;
  final DateTime createdAt;
  final DateTime lastAccess;
  final String? title;
  final String? author;
  final String? coverUrl;

  DownloadEntry({
    required this.bookId,
    required this.path,
    required this.bytes,
    required this.createdAt,
    required this.lastAccess,
    this.title,
    this.author,
    this.coverUrl,
  });

  DownloadEntry copyWith({DateTime? lastAccess}) => DownloadEntry(
    bookId: bookId,
    path: path,
    bytes: bytes,
    createdAt: createdAt,
    lastAccess: lastAccess ?? this.lastAccess,
    title: title,
    author: author,
    coverUrl: coverUrl,
  );

  Map<String, dynamic> toJson() => {
    'bookId': bookId,
    'path': path,
    'bytes': bytes,
    'createdAt': createdAt.toIso8601String(),
    'lastAccess': lastAccess.toIso8601String(),
    'title': title,
    'author': author,
    'coverUrl': coverUrl,
  };

  static DownloadEntry fromJson(Map<String, dynamic> j) => DownloadEntry(
    bookId: j['bookId'] as String,
    path: j['path'] as String,
    bytes: j['bytes'] as int,
    createdAt: DateTime.parse(j['createdAt'] as String),
    lastAccess: DateTime.parse(j['lastAccess'] as String),
    title: j['title'] as String?,
    author: j['author'] as String?,
    coverUrl: j['coverUrl'] as String?,
  );
}

class DownloadsIndex {
  final Map<String, DownloadEntry> byBookId;
  DownloadsIndex(this.byBookId);

  int get totalBytes => byBookId.values.fold(0, (a, e) => a + e.bytes);

  Map<String, dynamic> toJson() =>
      byBookId.map((k, v) => MapEntry(k, v.toJson()));

  static DownloadsIndex fromJson(Map<String, dynamic> j) => DownloadsIndex(
    j.map(
      (k, v) => MapEntry(
        k,
        DownloadEntry.fromJson((v as Map).cast<String, dynamic>()),
      ),
    ),
  );
}

class DownloadedBooksStore {
  final SharedPreferences _prefs;
  final int maxBytes; // e.g. 250MB
  late final Directory _baseDir;

  DownloadedBooksStore(this._prefs, {required this.maxBytes});

  Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    _baseDir = Directory(p.join(docs.path, 'books'));
    if (!await _baseDir.exists()) {
      await _baseDir.create(recursive: true);
    }
    // cleanup missing files
    final idx = await _readIndex();
    final cleaned = Map<String, DownloadEntry>.from(idx.byBookId);
    for (final e in idx.byBookId.values) {
      if (!File(e.path).existsSync()) cleaned.remove(e.bookId);
    }
    await _writeIndex(DownloadsIndex(cleaned));
  }

  Future<String> targetPath(String bookId, {String ext = 'epub'}) async {
    final safe = bookId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return p.join(_baseDir.path, '$safe.$ext');
  }

  Future<DownloadsIndex> _readIndex() async {
    final raw = _prefs.getString(_kDownloadsIndexKey);
    if (raw == null) return DownloadsIndex({});
    final map = (json.decode(raw) as Map).cast<String, dynamic>();
    return DownloadsIndex.fromJson(map);
  }

  Future<void> _writeIndex(DownloadsIndex idx) async {
    await _prefs.setString(_kDownloadsIndexKey, json.encode(idx.toJson()));
  }

  Future<List<DownloadEntry>> list() async {
    final list = (await _readIndex()).byBookId.values.toList();
    list.sort((a, b) => (a.title ?? a.bookId).compareTo(b.title ?? b.bookId));
    return list;
  }

  Future<bool> isDownloaded(String bookId) async =>
      (await _readIndex()).byBookId.containsKey(bookId);

  Future<void> touch(String bookId) async {
    final idx = await _readIndex();
    final e = idx.byBookId[bookId];
    if (e == null) return;
    idx.byBookId[bookId] = e.copyWith(lastAccess: DateTime.now());
    await _writeIndex(idx);
  }

  /// Existing API: write bytes then index
  Future<DownloadEntry> saveBytes({
    required String bookId,
    required List<int> bytes,
    String? ext,
    String? title,
    String? author,
    String? coverUrl,
  }) async {
    final path = await targetPath(bookId, ext: ext ?? 'bin');
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);

    final stat = await file.stat();
    final now = DateTime.now();
    final entry = DownloadEntry(
      bookId: bookId,
      path: path,
      bytes: stat.size,
      createdAt: now,
      lastAccess: now,
      title: title,
      author: author,
      coverUrl: coverUrl,
    );

    final idx = await _readIndex();
    idx.byBookId[bookId] = entry;
    await _writeIndex(idx);
    await _enforceLru();
    return entry;
  }

  /// ✅ NEW: index an already-downloaded file without re-reading bytes
  Future<DownloadEntry> saveFromExistingFile({
    required String bookId,
    required String absolutePath,
    String? title,
    String? author,
    String? coverUrl,
  }) async {
    final file = File(absolutePath);
    final stat = await file.stat();
    final now = DateTime.now();
    final entry = DownloadEntry(
      bookId: bookId,
      path: absolutePath,
      bytes: stat.size,
      createdAt: now,
      lastAccess: now,
      title: title,
      author: author,
      coverUrl: coverUrl,
    );

    final idx = await _readIndex();
    idx.byBookId[bookId] = entry;
    await _writeIndex(idx);
    await _enforceLru();
    return entry;
  }

  Future<void> delete(String bookId) async {
    final idx = await _readIndex();
    final e = idx.byBookId.remove(bookId);
    if (e != null) {
      final f = File(e.path);
      if (await f.exists()) await f.delete();
      await _writeIndex(idx);
    }
  }

  Future<void> _enforceLru() async {
    var idx = await _readIndex();
    var total = idx.totalBytes;
    if (total <= maxBytes) return;

    final entries =
        idx.byBookId.values.toList()..sort(
          (a, b) => a.lastAccess.compareTo(b.lastAccess),
        ); // oldest first

    for (final e in entries) {
      final f = File(e.path);
      if (await f.exists()) await f.delete();
      idx.byBookId.remove(e.bookId);
      total -= e.bytes;
      if (total <= maxBytes) break;
    }
    await _writeIndex(idx);
  }
}

/// Providers
final downloadsMaxBytesProvider = Provider<int>((ref) => 250 * 1024 * 1024);

final downloadedBooksStoreProvider = Provider<DownloadedBooksStore>((ref) {
  final sp = ref.watch(sharedPrefsProvider);
  final max = ref.watch(downloadsMaxBytesProvider);
  return DownloadedBooksStore(sp, maxBytes: max);
});

final downloadedInitProvider = FutureProvider<void>((ref) async {
  await ref.read(downloadedBooksStoreProvider).init();
});

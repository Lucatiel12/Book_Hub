import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:book_hub/features/profile/profile_stats_provider.dart';

import 'package:book_hub/managers/downloaded_books_manager.dart';
import 'package:book_hub/services/storage/downloaded_books_store.dart';
import 'package:book_hub/features/books/providers/saved_downloaded_providers.dart';
import 'package:book_hub/features/settings/settings_provider.dart';
import 'package:book_hub/services/notifications/notification_service.dart';
import 'package:book_hub/services/permissions/permission_service.dart';

enum DownloadStatus { queued, downloading, paused, completed, failed, canceled }

class ActiveDownload {
  final String bookId;
  final String title;
  final String author;
  final String? coverUrl;
  final String? url; // null → placeholder/local bytes
  final String ext; // 'epub' | 'pdf' | 'txt'
  final CancelToken cancelToken;

  final double? progress; // 0..1 or null if unknown
  final DownloadStatus status;
  final String? error;

  ActiveDownload({
    required this.bookId,
    required this.title,
    required this.author,
    this.coverUrl,
    this.url,
    required this.ext,
    required this.cancelToken,
    this.progress,
    this.status = DownloadStatus.queued,
    this.error,
  });

  ActiveDownload copyWith({
    double? progress,
    DownloadStatus? status,
    String? error,
    CancelToken? cancelToken,
    String? url,
  }) {
    return ActiveDownload(
      bookId: bookId,
      title: title,
      author: author,
      coverUrl: coverUrl,
      url: url ?? this.url,
      ext: ext,
      cancelToken: cancelToken ?? this.cancelToken,
      progress: progress,
      status: status ?? this.status,
      error: error,
    );
  }
}

class DownloadController extends StateNotifier<List<ActiveDownload>> {
  final Ref ref;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  // Throttle progress emissions
  final Map<String, DateTime> _lastProgressEmit = {};

  DownloadController(this.ref) : super(const []) {
    // Auto-restore on launch (from settings)
    final autoRestore = ref.read(downloadSettingsProvider).autoRestoreOnLaunch;
    if (autoRestore) {
      unawaited(() async {
        await _restorePendingFromDisk();
        await _maybeAutoResumeWaitingForWifi();
      }());
    }

    // React to connectivity changes (resume when Wi-Fi appears)
    _connSub = Connectivity().onConnectivityChanged.listen((results) async {
      final settings = ref.read(downloadSettingsProvider);
      if (!settings.autoRetry) return;
      final isWifi = results.contains(ConnectivityResult.wifi);
      if (isWifi) {
        await _maybeAutoResumeWaitingForWifi();
      }
    });

    // React to settings changes immediately
    ref.listen(downloadSettingsProvider, (prev, next) {
      // Concurrency changed → try to fill slots
      if (prev == null || prev.maxConcurrent != next.maxConcurrent) {
        _schedule();
      }

      // Wi-Fi-only toggled
      if (prev == null || prev.wifiOnly != next.wifiOnly) {
        Connectivity().checkConnectivity().then((results) {
          final isWifi = results.contains(ConnectivityResult.wifi);
          if (next.wifiOnly && !isWifi) {
            // Pause active downloads and mark reason
            for (final d in state.where(
              (x) => x.status == DownloadStatus.downloading,
            )) {
              pause(d.bookId);
              _upsert(
                d.copyWith(
                  status: DownloadStatus.paused,
                  error: 'Waiting for Wi-Fi',
                ),
              );
            }
          } else {
            // Wi-Fi available or requirement off → resume queued/paused
            _maybeAutoResumeWaitingForWifi();
            _schedule();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  static const List<Duration> _retryDelays = [
    Duration(seconds: 20),
    Duration(minutes: 1),
  ];

  void _upsert(ActiveDownload d) {
    final i = state.indexWhere((x) => x.bookId == d.bookId);
    if (i == -1) {
      state = [...state, d];
    } else {
      final copy = [...state];
      copy[i] = d;
      state = copy;
    }
  }

  void _remove(String bookId) {
    state = state.where((d) => d.bookId != bookId).toList();
  }

  Future<Directory> _booksDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'books'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> _finalPathFor(String bookId, String ext) async {
    return ref.read(downloadedBooksStoreProvider).targetPath(bookId, ext: ext);
  }

  String _safeId(String bookId) =>
      bookId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');

  String _metaPathFromFinal(String finalPath) => '$finalPath.meta.json';
  String _partPathFromFinal(String finalPath) => '$finalPath.part';

  bool _isNetworkError(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout;

  Future<void> _writeMeta(ActiveDownload task) async {
    if (task.url == null || task.url!.isEmpty) return;
    final finalPath = await _finalPathFor(task.bookId, task.ext);
    final metaFile = File(_metaPathFromFinal(finalPath));
    final meta = {
      'bookId': task.bookId,
      'title': task.title,
      'author': task.author,
      'coverUrl': task.coverUrl,
      'url': task.url,
      'ext': task.ext,
    };
    await metaFile.writeAsString(json.encode(meta), flush: true);
  }

  Future<void> _removeSidecarAndPart(String bookId, String ext) async {
    final finalPath = await _finalPathFor(bookId, ext);
    final metaFile = File(_metaPathFromFinal(finalPath));
    final partFile = File(_partPathFromFinal(finalPath));
    if (await metaFile.exists()) await metaFile.delete();
    if (await partFile.exists()) await partFile.delete();
  }

  Future<void> _restorePendingFromDisk() async {
    try {
      final dir = await _booksDir();
      final entries = await dir.list(followLinks: false).toList();

      for (final ent in entries) {
        if (ent is! File) continue;
        final path = ent.path;
        if (!path.endsWith('.part')) continue;

        final finalPath = path.substring(0, path.length - '.part'.length);
        final metaPath = _metaPathFromFinal(finalPath);
        final metaFile = File(metaPath);

        String? bookId;
        String title = 'Unknown';
        String author = 'Unknown';
        String? coverUrl;
        String? url;
        String ext = p.extension(finalPath).replaceFirst('.', '');
        if (ext.isEmpty) ext = 'bin';

        if (await metaFile.exists()) {
          try {
            final meta = json.decode(await metaFile.readAsString()) as Map;
            bookId = (meta['bookId'] as String?)?.trim();
            title = (meta['title'] as String?)?.trim() ?? title;
            author = (meta['author'] as String?)?.trim() ?? author;
            coverUrl = (meta['coverUrl'] as String?)?.trim();
            url = (meta['url'] as String?)?.trim();
            ext = (meta['ext'] as String?)?.trim() ?? ext;
          } catch (_) {}
        }

        final String resolvedBookId =
            bookId ?? p.basenameWithoutExtension(finalPath);
        if (title == 'Unknown') title = resolvedBookId;

        final exists = state.any(
          (d) =>
              d.bookId == resolvedBookId &&
              (d.status == DownloadStatus.queued ||
                  d.status == DownloadStatus.downloading ||
                  d.status == DownloadStatus.paused),
        );
        if (exists) continue;

        final task = ActiveDownload(
          bookId: resolvedBookId,
          title: title,
          author: author,
          coverUrl: coverUrl,
          url: url,
          ext: ext,
          cancelToken: CancelToken(),
          progress: null,
          status: DownloadStatus.paused,
        );
        _upsert(task);
      }
    } catch (_) {
      // ignore scan errors
    }
  }

  Future<void> _maybeAutoResumeWaitingForWifi() async {
    final settings = ref.read(downloadSettingsProvider);

    if (!settings.autoRetry) return;

    if (settings.wifiOnly) {
      final results = await Connectivity().checkConnectivity();
      final isWifi = results.contains(ConnectivityResult.wifi);
      if (!isWifi) return; // still not on Wi-Fi → do nothing
    }

    final toResume =
        state
            .where(
              (d) =>
                  d.status == DownloadStatus.paused &&
                  (d.error?.trim() == 'Waiting for Wi-Fi'),
            )
            .toList();

    for (final d in toResume) {
      final fresh = d.copyWith(
        status: DownloadStatus.queued,
        cancelToken: CancelToken(),
      );
      _upsert(fresh);
      _runWithRetries(fresh);
    }
  }

  int get _activeCount =>
      state.where((d) => d.status == DownloadStatus.downloading).length;

  Iterable<ActiveDownload> get _queued =>
      state.where((d) => d.status == DownloadStatus.queued);

  void _schedule() {
    final max = ref.read(downloadSettingsProvider).maxConcurrent;
    var slots = (max - _activeCount);
    if (slots <= 0) return;

    // start oldest queued first
    for (final d in _queued) {
      if (slots <= 0) break;
      // guard: ensure not already running
      final fresh = d.copyWith(
        status: DownloadStatus.queued,
        cancelToken: CancelToken(),
        url: d.url,
      );
      _upsert(fresh);
      _runWithRetries(fresh); // will flip to downloading internally
      slots--;
    }
  }

  // --- Public API ---

  Future<void> start({
    required String bookId,
    required String title,
    required String author,
    String? coverUrl,
    String? url,
    String ext = 'epub',
  }) async {
    // Safeguard: Ensure store is ready even if app forgot to call downloadedInitProvider.
    await ref.read(downloadedBooksStoreProvider).init();

    final exists = state.any(
      (d) =>
          d.bookId == bookId &&
          (d.status == DownloadStatus.queued ||
              d.status == DownloadStatus.downloading ||
              d.status == DownloadStatus.paused),
    );
    if (exists) return;

    final task = ActiveDownload(
      bookId: bookId,
      title: title,
      author: author,
      coverUrl: coverUrl,
      url: url,
      ext: ext,
      cancelToken: CancelToken(),
      progress: 0.0,
      status: DownloadStatus.queued,
    );
    _upsert(task);

    // Ask for Android 13+ notifications permission when user initiates downloads.
    await PermissionService.instance.ensureNotificationPermission();
    await _writeMeta(task);
    _schedule();
  }

  Future<void> _runWithRetries(ActiveDownload task) async {
    final autoRetry = ref.read(downloadSettingsProvider).autoRetry;

    final done = await _attempt(task);
    if (done || !autoRetry) return;

    for (final delay in _retryDelays) {
      // stop if user paused/canceled meanwhile
      final current = state.firstWhere(
        (d) => d.bookId == task.bookId,
        orElse: () => task,
      );
      if (current.status == DownloadStatus.paused ||
          current.status == DownloadStatus.canceled) {
        return;
      }

      await Future.delayed(delay);

      final fresh = current.copyWith(
        status: DownloadStatus.queued,
        cancelToken: CancelToken(),
      );
      _upsert(fresh);

      final ok = await _attempt(fresh);
      if (ok) return;
    }

    final endState = state.firstWhere(
      (d) => d.bookId == task.bookId,
      orElse: () => task,
    );
    _upsert(
      endState.copyWith(
        status: DownloadStatus.paused,
        error: 'Auto-paused after retries',
      ),
    );
    await NotificationService.instance.showFailed(
      endState.bookId,
      endState.title,
      reason: 'Auto-paused after retries',
    );
    _schedule();
  }

  Future<bool> _attempt(ActiveDownload task) async {
    _upsert(task = task.copyWith(status: DownloadStatus.downloading));

    // Wi-Fi only check before network
    final wifiOnly = ref.read(downloadSettingsProvider).wifiOnly;
    if (wifiOnly) {
      final results = await Connectivity().checkConnectivity();
      final isWifi = results.contains(ConnectivityResult.wifi);

      if (!isWifi) {
        _upsert(
          task.copyWith(
            status: DownloadStatus.paused,
            error: 'Waiting for Wi-Fi',
          ),
        );
        await NotificationService.instance.showPausedForWifi(
          task.bookId,
          task.title,
        );
        return false; // scheduler/backoff will handle later
      }
    }

    try {
      if (task.url != null && task.url!.isNotEmpty) {
        await ref
            .read(downloadedBooksManagerProvider)
            .downloadResumable(
              bookId: task.bookId,
              url: task.url!,
              ext: task.ext,
              title: task.title,
              author: task.author,
              coverUrl: task.coverUrl,
              cancelToken: task.cancelToken,
              onProgress: (received, total) {
                if (task.cancelToken.isCancelled) return;
                if (total > 0) {
                  final pVal = (received / total).clamp(0.0, 1.0);
                  final now = DateTime.now();
                  final last = _lastProgressEmit[task.bookId];
                  if (last == null ||
                      now.difference(last).inMilliseconds >= 120 ||
                      (task.progress == null ||
                          (pVal - (task.progress ?? 0)).abs() >= 0.01)) {
                    _lastProgressEmit[task.bookId] = now;
                    _upsert(task = task.copyWith(progress: pVal));
                  }
                } else {
                  _upsert(task = task.copyWith(progress: null));
                }
              },
            );
      } else {
        // placeholder branch unchanged
        for (int i = 1; i <= 20; i++) {
          await Future.delayed(const Duration(milliseconds: 80));
          if (task.cancelToken.isCancelled) {
            _upsert(task.copyWith(status: DownloadStatus.paused));
            return false;
          }
          _upsert(task = task.copyWith(progress: i / 20));
        }
        final docs = await getApplicationDocumentsDirectory();
        final path = p.join(
          docs.path,
          'books',
          '${_safeId(task.bookId)}.${task.ext}',
        );
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(
          utf8.encode("Offline placeholder for ${task.title}"),
        );
        await ref
            .read(downloadedBooksStoreProvider)
            .saveFromExistingFile(
              bookId: task.bookId,
              absolutePath: path,
              title: task.title,
              author: task.author,
              coverUrl: task.coverUrl,
            );
      }

      // Mark success before invalidating others
      _upsert(
        task = task.copyWith(progress: 1.0, status: DownloadStatus.completed),
      );

      // Only invalidate, never read dependent providers
      Future.microtask(() {
        ref.invalidate(isBookDownloadedProvider(task.bookId));
        ref.invalidate(profileStatsProvider);
        ref.invalidate(downloadedListProvider);
      });

      await _removeSidecarAndPart(task.bookId, task.ext);

      await NotificationService.instance.showCompleted(task.bookId, task.title);

      await Future.delayed(const Duration(seconds: 2));
      _remove(task.bookId);
      _schedule();
      return true;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        final current = state.firstWhere(
          (x) => x.bookId == task.bookId,
          orElse: () => task,
        );
        final st =
            current.status == DownloadStatus.paused
                ? DownloadStatus.paused
                : DownloadStatus.canceled;
        _upsert(task.copyWith(status: st, error: 'Canceled'));
        return false;
      } else if (_isNetworkError(e)) {
        // TRANSIENT: keep queued so backoff in _runWithRetries can retry
        _upsert(
          task.copyWith(
            status: DownloadStatus.queued,
            error: 'Network error – retrying…',
            cancelToken: CancelToken(),
          ),
        );
        return false;
      } else {
        // Check if file exists before marking as failed
        final isOnDevice = await _isOnDevice(task.bookId);
        if (isOnDevice) {
          // File exists, mark as completed despite the error
          _upsert(
            task.copyWith(progress: 1.0, status: DownloadStatus.completed),
          );
          Future.microtask(() {
            ref.invalidate(isBookDownloadedProvider(task.bookId));
            ref.invalidate(profileStatsProvider);
            ref.invalidate(downloadedListProvider);
          });
          return true;
        } else {
          // PERMANENT: mark failed and stop
          _upsert(
            task.copyWith(status: DownloadStatus.failed, error: e.message),
          );
          await NotificationService.instance.showFailed(
            task.bookId,
            task.title,
            reason: e.message,
          );
          return true;
        }
      }
    } catch (e) {
      // Check if file exists before marking as failed
      final isOnDevice = await _isOnDevice(task.bookId);
      if (isOnDevice) {
        // File exists, mark as completed despite the error
        _upsert(task.copyWith(progress: 1.0, status: DownloadStatus.completed));
        Future.microtask(() {
          ref.invalidate(isBookDownloadedProvider(task.bookId));
          ref.invalidate(profileStatsProvider);
          ref.invalidate(downloadedListProvider);
        });
        return true;
      } else {
        _upsert(task.copyWith(status: DownloadStatus.failed, error: '$e'));
        await NotificationService.instance.showFailed(
          task.bookId,
          task.title,
          reason: '$e',
        );
        return true;
      }
    }
  }

  /// Check if file exists on device
  Future<bool> _isOnDevice(String bookId) async {
    try {
      final store = ref.read(downloadedBooksStoreProvider);
      final entry = await store.getByBookId(bookId);
      if (entry == null) return false;
      final file = File(entry.path);
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  /// Cancel completely: abort and remove file, .part and .meta
  Future<void> cancel(String bookId) async {
    final d = state.firstWhere(
      (x) => x.bookId == bookId,
      orElse: () => throw StateError('Download not found'),
    );
    d.cancelToken.cancel();
    _upsert(d.copyWith(status: DownloadStatus.canceled));

    await ref.read(downloadedBooksManagerProvider).delete(bookId);
    await _removeSidecarAndPart(bookId, d.ext);
    _schedule();
  }

  /// Pause: abort network but keep .part and .meta
  void pause(String bookId) {
    final d = state.firstWhere(
      (x) => x.bookId == bookId,
      orElse: () => throw StateError('Download not found'),
    );
    _upsert(d.copyWith(status: DownloadStatus.paused));
    d.cancelToken.cancel();
    _schedule();
  }

  /// Resume: re-queue with fresh CancelToken
  void resume(String bookId) {
    final d = state.firstWhere(
      (x) => x.bookId == bookId,
      orElse: () => throw StateError('Download not found'),
    );
    final fresh = d.copyWith(
      status: DownloadStatus.queued,
      cancelToken: CancelToken(),
      url: d.url,
    );
    _upsert(fresh);
    _runWithRetries(fresh);
  }

  /// Clear any download state for a specific book (used when book is deleted)
  void clearFor(String bookId) {
    final existing = state.firstWhere(
      (x) => x.bookId == bookId,
      orElse: () => throw StateError('Download not found'),
    );

    // Cancel if active
    if (existing.status == DownloadStatus.downloading) {
      existing.cancelToken.cancel();
    }

    // Remove from state
    _remove(bookId);
    _schedule();
  }

  void clearCompleted() {
    state = state.where((d) => d.status != DownloadStatus.completed).toList();
  }
}

/// Provider
final downloadControllerProvider =
    StateNotifierProvider<DownloadController, List<ActiveDownload>>(
      (ref) => DownloadController(ref),
    );

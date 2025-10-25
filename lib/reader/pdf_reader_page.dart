// lib/reader/pdf_reader_page.dart
import 'package:flutter/material.dart';
import 'package:book_hub/features/reading/reading_models.dart';
import 'package:book_hub/features/reading/reading_providers.dart';
import 'package:book_hub/features/reading/reading_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reader_models.dart' as rm; // 👈 alias
import 'reader_bookmarks_store.dart';
import 'package:book_hub/services/storage/reading_history_store.dart';
import 'package:book_hub/models/history_entry.dart';

class PdfReaderPage extends ConsumerStatefulWidget {
  final rm.ReaderSource src; // 👈 use alias type
  const PdfReaderPage({super.key, required this.src});

  @override
  ConsumerState<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends ConsumerState<PdfReaderPage> {
  late final PdfControllerPinch _ctrl;
  ReaderBookmarksStore? _store;
  bool _storeReady = false;
  int _currentPage = 1;
  _ReaderSession? _session; // for backend saves
  int? _totalPages; // set when doc loads

  @override
  void initState() {
    super.initState();
    _ctrl = PdfControllerPinch(document: PdfDocument.openFile(widget.src.path));
    _initStoreAndResume();

    // 🔸 LOCAL HISTORY UPSERT
    try {
      final store = ref.read(readingHistoryStoreProvider);
      store.upsert(
        HistoryEntry(
          bookId: widget.src.bookId,
          title: widget.src.title,
          author: '', // add if you have it on ReaderSource
          coverUrl: null, // add if you have it on ReaderSource
          openedAtMillis: DateTime.now().millisecondsSinceEpoch,
          chapterIndex: 0, // PDFs don’t have chapters; keep 0
          scrollProgress: 0.0, // will be updated as pages change
        ),
      );
    } catch (_) {}

    // 🔗 create session from Riverpod
    final repo = ref.read(readingRepositoryProvider);
    _session = _ReaderSession(bookId: widget.src.bookId, repo: repo);

    // Do network calls after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _session?.onOpen(); // POST /history
      final prog = await _session?.loadProgress(); // GET /progress

      // If server has a page in locator, go there first
      final serverPage = (prog?.locator?['page'] as num?)?.toInt();
      if (serverPage != null && serverPage >= 1) {
        _currentPage = serverPage;
        _ctrl.jumpToPage(serverPage);
        return;
      }

      // If percent only, approximate to a page once we know total pages
      if (prog?.percent != null && prog!.percent > 0 && _totalPages != null) {
        final approx = (prog.percent.clamp(0.0, 1.0) * _totalPages!)
            .ceil()
            .clamp(1, _totalPages!);
        _currentPage = approx;
        _ctrl.jumpToPage(approx);
      }
    });
  }

  Future<void> _initStoreAndResume() async {
    final sp = await SharedPreferences.getInstance();
    _store = ReaderBookmarksStore(sp);
    final last = await _store!.getLast(widget.src.bookId);
    if (!mounted) return;
    if (last?.pdfPage != null && last!.pdfPage! >= 1) {
      _currentPage = last.pdfPage!;
      _ctrl.jumpToPage(_currentPage);
    }
    setState(() => _storeReady = true);
  }

  @override
  void dispose() {
    // flush last position
    final total = _totalPages ?? 0;
    if (total > 0) {
      final pct = _overallPercentFromPages(_currentPage, total);
      _session?.onPosition(percent: pct, locator: {'page': _currentPage});
    }
    _session?.onClose();

    _ctrl.dispose();
    super.dispose();
  }

  double _overallPercentFromPages(int page, int total) {
    if (total <= 0) return 0.0;
    final p = (page - 1) / total; // 0-based → 0..(1 - 1/total)
    return p.clamp(0.0, 1.0);
  }

  Future<void> _addBookmark() async {
    if (!_storeReady || _store == null) return;
    await _store!.add(
      rm.ReaderBookmark(
        bookId: widget.src.bookId,
        format: rm.ReaderFormat.pdf,
        pdfPage: _currentPage,
        pdfOffset: null,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Bookmark added')));
  }

  Future<void> _openBookmarks() async {
    if (!_storeReady || _store == null) return;
    final items = await _store!.list(widget.src.bookId);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder:
          (ctx) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (ctx, i) {
              final bm = items[i];
              if (bm.format != rm.ReaderFormat.pdf) {
                return const SizedBox.shrink();
              }
              final page = (bm.pdfPage ?? 1).clamp(1, 1 << 20);
              return ListTile(
                leading: const Icon(Icons.bookmark),
                title: Text('Page $page'),
                onTap: () {
                  Navigator.pop(ctx);
                  _ctrl.jumpToPage(page);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await _store!.removeAt(widget.src.bookId, i);
                    if (!context.mounted) return;
                    Navigator.pop(ctx);
                    _openBookmarks();
                  },
                ),
              );
            },
          ),
    );
  }

  Future<void> _persistLastPage(int page) async {
    if (!_storeReady || _store == null) return;
    await _store!.setLast(
      widget.src.bookId,
      rm.ReaderBookmark(
        bookId: widget.src.bookId,
        format: rm.ReaderFormat.pdf,
        pdfPage: page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.src.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Bookmarks',
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: _openBookmarks,
          ),
          IconButton(
            tooltip: 'Add bookmark',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: _addBookmark,
          ),
        ],
      ),
      body: PdfViewPinch(
        controller: _ctrl,
        onDocumentLoaded: (doc) {
          if (mounted) {
            setState(() {
              _totalPages = doc.pagesCount;
            });
          }
        },
        onPageChanged: (page) async {
          if (mounted) {
            setState(() {
              _currentPage = page;
            });
          }
          await _persistLastPage(page);

          try {
            final total = _totalPages ?? 0;
            final store = ref.read(readingHistoryStoreProvider);
            await store.upsert(
              HistoryEntry(
                bookId: widget.src.bookId,
                title: widget.src.title,
                author: '',
                coverUrl: null,
                openedAtMillis: DateTime.now().millisecondsSinceEpoch,
                chapterIndex: 0,
                scrollProgress:
                    (total > 0)
                        ? _overallPercentFromPages(_currentPage, total)
                        : 0.0,
              ),
            );
          } catch (_) {}

          // 🔁 send progress to backend
          final total = _totalPages ?? 0;
          if (total > 0) {
            final percent = _overallPercentFromPages(_currentPage, total);
            _session?.onPosition(
              percent: percent,
              locator: {'page': _currentPage},
            );
          }
        },
      ),
    );
  }
}

class _ReaderSession {
  final String bookId;
  final ReadingRepository repo;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);
  Map<String, dynamic>? _lastLocator;
  double _lastPercent = 0.0;

  _ReaderSession({required this.bookId, required this.repo});

  Future<void> onOpen() async {
    try {
      await repo.logHistory(bookId);
    } catch (_) {}
  }

  Future<ReadingProgressDto?> loadProgress() async {
    try {
      return await repo.getProgress(bookId);
    } catch (_) {
      return null;
    }
  }

  Future<void> onPosition({
    required double percent,
    Map<String, dynamic>? locator,
  }) async {
    final p = percent.clamp(0.0, 1.0);
    _lastPercent = p;
    _lastLocator = locator;
    final now = DateTime.now();
    if (now.difference(_lastSave).inSeconds >= 5) {
      _lastSave = now;
      try {
        await repo.saveProgress(
          bookId,
          percent: _lastPercent,
          locator: _lastLocator,
          format: 'pdf',
        );
      } catch (_) {}
    }
  }

  Future<void> onClose() async {
    try {
      await repo.saveProgress(
        bookId,
        percent: _lastPercent,
        locator: _lastLocator,
        format: 'pdf',
      );
    } catch (_) {}
  }
}

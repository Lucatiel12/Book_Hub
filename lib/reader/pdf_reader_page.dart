// lib/reader/pdf_reader_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reader_models.dart' as rm; // alias
import 'reader_bookmarks_store.dart';
import 'package:book_hub/models/history_entry.dart';
import 'package:book_hub/features/reading/reading_providers.dart';
import 'package:book_hub/features/reading/reading_repository.dart';
import 'package:book_hub/features/reading/reading_models.dart';
import 'package:book_hub/services/storage/reading_history_store.dart';

class PdfReaderPage extends ConsumerStatefulWidget {
  final rm.ReaderSource src;
  const PdfReaderPage({super.key, required this.src});

  @override
  ConsumerState<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends ConsumerState<PdfReaderPage> {
  late final PdfControllerPinch _ctrl;
  ReaderBookmarksStore? _store;
  bool _storeReady = false;
  int _currentPage = 1;
  int? _totalPages;
  _ReaderSession? _session;

  @override
  void initState() {
    super.initState();
    _ctrl = PdfControllerPinch(document: PdfDocument.openFile(widget.src.path));
    _initStoreAndResume();

    // Local history snapshot
    try {
      final history = ref.read(readingHistoryStoreProvider);
      history.upsert(
        HistoryEntry(
          bookId: widget.src.bookId,
          title: widget.src.title,
          author: '',
          coverUrl: null,
          openedAtMillis: DateTime.now().millisecondsSinceEpoch,
          chapterIndex: 0,
          scrollProgress: 0.0,
        ),
      );
    } catch (_) {}

    // Backend session
    final repo = ref.read(readingRepositoryProvider);
    _session = _ReaderSession(bookId: widget.src.bookId, repo: repo);

    // Resume from server if available
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _session?.onOpen();
      final prog = await _session?.loadProgress();

      final serverPage = (prog?.locator?['page'] as num?)?.toInt();
      if (serverPage != null && serverPage >= 1) {
        _currentPage = serverPage;
        _ctrl.jumpToPage(serverPage);
        return;
      }

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
    final total = _totalPages ?? 0;
    if (total > 0) {
      final pct = _progressPercent(_currentPage, total);
      _session?.onPosition(percent: pct, locator: {'page': _currentPage});
    }
    _session?.onClose();
    _ctrl.dispose();
    super.dispose();
  }

  double _progressPercent(int page, int total) {
    if (total <= 0) return 0.0;
    return ((page - 1) / total).clamp(0.0, 1.0);
  }

  // ---------- Page nav ----------
  void _goDelta(int delta) {
    if (_totalPages == null) return;
    final next = (_currentPage + delta).clamp(1, _totalPages!);
    if (next != _currentPage) {
      _ctrl.jumpToPage(next);
    }
  }

  Future<void> _jumpToPageDialog() async {
    if (_totalPages == null || _totalPages == 0) return;
    final tc = TextEditingController(text: _currentPage.toString());
    final formKey = GlobalKey<FormState>();

    final picked = await showDialog<int>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Go to page'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: tc,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '1 – ${_totalPages!}',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null) return 'Enter a number';
                  if (n < 1 || n > _totalPages!) {
                    return 'Must be 1–${_totalPages!}';
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(ctx).pop(int.parse(tc.text.trim()));
                  }
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx, int.parse(tc.text.trim()));
                  }
                },
                child: const Text('Go'),
              ),
            ],
          ),
    );

    if (picked != null) {
      _ctrl.jumpToPage(picked);
    }
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
        title: Text(
          '${widget.src.title} • $_currentPage of ${_totalPages ?? 0}',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Go to page…',
            icon: const Icon(Icons.dialpad), // simple page-jump icon
            onPressed: (_totalPages ?? 0) == 0 ? null : _jumpToPageDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PdfViewPinch(
              controller: _ctrl,
              onDocumentLoaded: (doc) {
                if (mounted) setState(() => _totalPages = doc.pagesCount);
              },
              onPageChanged: (page) async {
                if (mounted) setState(() => _currentPage = page);
                await _persistLastPage(page);

                try {
                  final total = _totalPages ?? 0;
                  final history = ref.read(readingHistoryStoreProvider);
                  await history.upsert(
                    HistoryEntry(
                      bookId: widget.src.bookId,
                      title: widget.src.title,
                      author: '',
                      coverUrl: null,
                      openedAtMillis: DateTime.now().millisecondsSinceEpoch,
                      chapterIndex: 0,
                      scrollProgress:
                          (total > 0)
                              ? _progressPercent(_currentPage, total)
                              : 0.0,
                    ),
                  );
                } catch (_) {}

                final total = _totalPages ?? 0;
                if (total > 0) {
                  final percent = _progressPercent(_currentPage, total);
                  _session?.onPosition(
                    percent: percent,
                    locator: {'page': _currentPage},
                  );
                }
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: .4),
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous page',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: (_currentPage > 1) ? () => _goDelta(-1) : null,
                  ),
                  Expanded(
                    child:
                        (_totalPages == null || _totalPages! <= 1)
                            ? const SizedBox.shrink()
                            : Slider(
                              value:
                                  _currentPage
                                      .clamp(1, _totalPages!)
                                      .toDouble(),
                              min: 1,
                              max: _totalPages!.toDouble(),
                              divisions: _totalPages! - 1,
                              label: '$_currentPage',
                              onChanged:
                                  (v) =>
                                      setState(() => _currentPage = v.round()),
                              onChangeEnd: (v) => _ctrl.jumpToPage(v.round()),
                            ),
                  ),
                  IconButton(
                    tooltip: 'Next page',
                    icon: const Icon(Icons.chevron_right),
                    onPressed:
                        (_totalPages != null && _currentPage < _totalPages!)
                            ? () => _goDelta(1)
                            : null,
                  ),
                ],
              ),
            ),
          ),
        ],
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

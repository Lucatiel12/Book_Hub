import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reader_models.dart' as rm; // 👈 alias
import 'reader_bookmarks_store.dart';

class PdfReaderPage extends StatefulWidget {
  final rm.ReaderSource src; // 👈 use alias type
  const PdfReaderPage({super.key, required this.src});

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  late final PdfControllerPinch _ctrl;
  ReaderBookmarksStore? _store;
  bool _storeReady = false;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _ctrl = PdfControllerPinch(document: PdfDocument.openFile(widget.src.path));
    _initStoreAndResume();
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
    _ctrl.dispose();
    super.dispose();
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
              if (bm.format != rm.ReaderFormat.pdf)
                return const SizedBox.shrink();
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
        onPageChanged: (page) async {
          _currentPage = page;
          await _persistLastPage(page);
        },
      ),
    );
  }
}

// lib/reader/pdf_reader_page.dart
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reader_models.dart';
import 'reader_bookmarks_store.dart';

class PdfReaderPage extends StatefulWidget {
  final ReaderSource src;
  const PdfReaderPage({super.key, required this.src});

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  late PdfControllerPinch _ctrl;
  late ReaderBookmarksStore _store;

  @override
  void initState() {
    super.initState();
    _ctrl = PdfControllerPinch(document: PdfDocument.openFile(widget.src.path));
    SharedPreferences.getInstance().then((sp) async {
      _store = ReaderBookmarksStore(sp);
      final last = await _store.getLast(widget.src.bookId);
      if (!mounted) return;
      if (last?.pdfPage != null) {
        _ctrl.jumpToPage(last!.pdfPage!);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _addBookmark() async {
    final page = _ctrl.page; // non-nullable; remove ?? 1
    await _store.add(
      ReaderBookmark(
        bookId: widget.src.bookId,
        format: ReaderFormat.pdf,
        pdfPage: page,
        pdfOffset: null,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Bookmark added')));
  }

  Future<void> _openBookmarks() async {
    final items = await _store.list(widget.src.bookId);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder:
          (_) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (ctx, i) {
              final bm = items[i];
              if (bm.format != ReaderFormat.pdf) return const SizedBox.shrink();
              return ListTile(
                leading: const Icon(Icons.bookmark),
                title: Text('Page ${bm.pdfPage ?? 1}'),
                onTap: () {
                  Navigator.pop(ctx);
                  final page = (bm.pdfPage ?? 1).clamp(1, 1 << 20);
                  _ctrl.jumpToPage(page);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await _store.removeAt(widget.src.bookId, i);
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
          await _store.setLast(
            widget.src.bookId,
            ReaderBookmark(
              bookId: widget.src.bookId,
              format: ReaderFormat.pdf,
              pdfPage: page,
            ),
          );
        },
      ),
    );
  }
}

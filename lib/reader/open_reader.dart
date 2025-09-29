import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reader_models.dart' as rm; // 👈 alias
import 'reader_bookmarks_store.dart';
import 'pdf_reader_page.dart';
import 'epub_reader_page.dart';
import 'package:book_hub/services/reader_prefs.dart';

class ReaderOpener {
  static Future<void> open(BuildContext context, rm.ReaderSource src) async {
    switch (src.format) {
      case rm.ReaderFormat.epub:
        final theme = await ReaderPrefs.getThemeMode();
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => EpubReaderPage(
                  bookId: src.bookId,
                  filePath: src.path,
                  theme: theme,
                ),
          ),
        );
        break;

      case rm.ReaderFormat.pdf:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => PdfReaderPage(src: src)));
        break;
    }
  }

  // If you keep a "bookmark current EPUB position" button:
  static Future<void> addEpubBookmark(String bookId, {String? label}) async {
    final sp = await SharedPreferences.getInstance();
    final store = ReaderBookmarksStore(sp);

    // EpubReaderPage stores CFI here:
    final cfi = sp.getString('epub_last_cfi_$bookId');
    if (cfi == null || cfi.isEmpty) return;

    // Your current model doesn’t have a `cfi` field—store as legacy locator JSON:
    final locatorJson = jsonEncode({'cfi': cfi});

    await store.add(
      rm.ReaderBookmark(
        bookId: bookId,
        format: rm.ReaderFormat.epub,
        epubLocator: locatorJson,
        note: label,
      ),
    );

    await store.setLast(
      bookId,
      rm.ReaderBookmark(
        bookId: bookId,
        format: rm.ReaderFormat.epub,
        epubLocator: locatorJson,
      ),
    );
  }
}

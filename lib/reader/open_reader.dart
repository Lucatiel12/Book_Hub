// lib/reader/open_reader.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

import 'reader_models.dart' as rm;
import 'reader_bookmarks_store.dart';
import 'pdf_reader_page.dart';
import 'epub_reader_page.dart';
import 'package:book_hub/services/reader_prefs.dart';

class ReaderOpener {
  static Future<void> open(BuildContext context, rm.ReaderSource src) async {
    debugPrint("Opening reader: ${src.title} (${src.format.name})");

    switch (src.format) {
      case rm.ReaderFormat.epub:
        {
          final theme = await ReaderPrefs.getThemeMode();
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) => EpubReaderPage(
                    bookId: src.bookId,
                    filePath: src.path,
                    theme: theme,
                    bookTitle: src.title,
                    author: src.author,
                    showProgressUI: false, // 👈 hide progress bars & % in EPUB
                  ),
            ),
          );
          break;
        }

      case rm.ReaderFormat.pdf:
        {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => PdfReaderPage(src: src)));
          break;
        }
    }
  }

  static Future<bool> openLocal(BuildContext context, String filePath) async {
    final ext = p.extension(filePath).toLowerCase();
    final baseName = p.basenameWithoutExtension(filePath);

    rm.ReaderFormat? fmt;
    if (ext == '.pdf') {
      fmt = rm.ReaderFormat.pdf;
    } else if (ext == '.epub') {
      fmt = rm.ReaderFormat.epub;
    } else {
      return false;
    }

    final localId = 'local:$baseName';

    final src = rm.ReaderSource(
      bookId: localId,
      title: baseName.isEmpty ? 'Local file' : baseName,
      author: null,
      path: filePath,
      format: fmt,
    );

    try {
      await open(context, src);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> addEpubBookmark(String bookId, {String? label}) async {
    final sp = await SharedPreferences.getInstance();
    final store = ReaderBookmarksStore(sp);

    final cfi = sp.getString('epub_last_cfi_$bookId');
    if (cfi == null || cfi.isEmpty) return;

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

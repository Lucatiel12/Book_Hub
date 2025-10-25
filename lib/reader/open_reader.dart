// lib/reader/open_reader.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p; // for extension/basename

import 'reader_models.dart' as rm; // alias
import 'reader_bookmarks_store.dart';
import 'pdf_reader_page.dart';
import 'epub_reader_page.dart';
import 'package:book_hub/services/reader_prefs.dart';

class ReaderOpener {
  /// Open a book using a prepared ReaderSource (local or already-resolved).
  /// No network calls here — just uses the IDs/paths provided.
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
                    bookId: src.bookId, // ✅ real backend (or stable local) ID
                    filePath: src.path, // local .epub path
                    theme: theme,
                    // pass metadata for nicer history (server + offline)
                    bookTitle: src.title,
                    author: src.author,
                    // coverUrl: (add here if your ReaderSource carries it)
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

  /// Open a **local** file directly by filesystem path.
  /// Builds a minimal ReaderSource with a stable local id.
  /// Returns `true` if the file type is supported and we attempted to open it.
  static Future<bool> openLocal(BuildContext context, String filePath) async {
    final ext = p.extension(filePath).toLowerCase();
    final baseName = p.basenameWithoutExtension(filePath);

    rm.ReaderFormat? fmt;
    if (ext == '.pdf') {
      fmt = rm.ReaderFormat.pdf;
    } else if (ext == '.epub') {
      fmt = rm.ReaderFormat.epub;
    } else {
      return false; // unsupported type
    }

    // Stable local id; adjust scheme if you prefer
    final localId = 'local:$baseName';

    final src = rm.ReaderSource(
      bookId: localId,
      title: baseName.isEmpty ? 'Local file' : baseName,
      author: null, // unknown for local imports
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

  /// Save an EPUB bookmark at the current position based on last persisted CFI.
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

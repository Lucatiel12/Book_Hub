// lib/reader/open_reader.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocsy_epub_viewer/epub_viewer.dart';

import 'reader_models.dart';
import 'reader_bookmarks_store.dart';
// 👇 add this import for the PDF page
import 'pdf_reader_page.dart';

class ReaderOpener {
  static StreamSubscription? _locatorSub;
  static String? _latestEpubLocatorJson;

  // ---------------- EPUB ----------------
  static Future<void> openEpub(BuildContext context, ReaderSource src) async {
    final sp = await SharedPreferences.getInstance();
    final store = ReaderBookmarksStore(sp);

    final last = await store.getLast(src.bookId);
    final String? lastJson = last?.epubLocator;

    EpubLocator? lastLoc;
    if (lastJson != null && lastJson.isNotEmpty) {
      final map = json.decode(lastJson) as Map<String, dynamic>;
      lastLoc = EpubLocator.fromJson(map);
    }

    VocsyEpub.setConfig(
      themeColor: Theme.of(context).colorScheme.primary,
      identifier: src.bookId,
      scrollDirection: EpubScrollDirection.ALLDIRECTIONS,
      allowSharing: false,
      enableTts: false,
      nightMode: false,
    );

    await _locatorSub?.cancel();
    _locatorSub = VocsyEpub.locatorStream.listen((locator) async {
      try {
        final locJson = jsonEncode((locator as EpubLocator).toJson());
        _latestEpubLocatorJson = locJson;
        await store.setLast(
          src.bookId,
          ReaderBookmark(
            bookId: src.bookId,
            format: ReaderFormat.epub,
            epubLocator: locJson,
          ),
        );
      } catch (_) {}
    });

    // returns void – do not await
    VocsyEpub.open(src.path, lastLocation: lastLoc);
  }

  /// Optional: call while EPUB is open (locator stream keeps latest location)
  static Future<void> addEpubBookmark(String bookId) async {
    final s = await SharedPreferences.getInstance();
    final store = ReaderBookmarksStore(s);
    if (_latestEpubLocatorJson == null) return;
    await store.add(
      ReaderBookmark(
        bookId: bookId,
        format: ReaderFormat.epub,
        epubLocator: _latestEpubLocatorJson,
      ),
    );
  }

  static Future<void> dispose() async {
    await _locatorSub?.cancel();
    _locatorSub = null;
  }

  // ---------------- ROUTER ----------------
  static Future<void> open(BuildContext context, ReaderSource src) async {
    switch (src.format) {
      case ReaderFormat.epub:
        await openEpub(context, src);
        break;
      case ReaderFormat.pdf:
        // PDF is a Flutter page
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => PdfReaderPage(src: src)));
        break;
    }
  }
}

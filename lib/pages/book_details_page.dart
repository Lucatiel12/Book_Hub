// lib/pages/book_details_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// backend
import 'package:book_hub/backend/backend_providers.dart';
// ✅ Updated imports
import 'package:book_hub/backend/book_repository.dart' show UiBook;
import 'package:book_hub/backend/models/dtos.dart'
    show ResourceDto, ResourceType;

// history/profile
import 'package:book_hub/features/history/history_provider.dart';
import 'package:book_hub/features/profile/profile_stats_provider.dart';

// downloads
import 'package:book_hub/features/downloads/downloads_button.dart';
import 'package:book_hub/features/downloads/download_controller.dart';

// saved/downloaded state
import 'package:book_hub/features/books/providers/saved_downloaded_providers.dart';
import 'package:book_hub/managers/saved_books_manager.dart';
import 'package:book_hub/managers/downloaded_books_manager.dart';

// reader
import 'package:book_hub/reader/reader_page.dart';
import 'package:book_hub/reader/epub_reader_page.dart';
import 'package:book_hub/services/reader_prefs.dart';

// local file store
import 'package:book_hub/services/storage/downloaded_books_store.dart';

// share
import 'package:share_plus/share_plus.dart';

/// Provide a single-book fetch
// ✅ Updated provider to return UiBook
final bookByIdProvider = FutureProvider.family<UiBook, String>((ref, id) async {
  final repo = ref.watch(bookRepositoryProvider);
  return repo.getById(id);
});

class BookDetailsPage extends ConsumerStatefulWidget {
  final String bookId; // real backend ID
  const BookDetailsPage({super.key, required this.bookId});

  @override
  ConsumerState<BookDetailsPage> createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends ConsumerState<BookDetailsPage> {
  List<String> _chapters = const [
    "Full Book",
  ]; // we'll show this until backend chapters exist

  // Pick best human-readable share URL/content
  // ✅ Updated parameter type to UiBook
  String _buildShareText(UiBook b, {String? link}) {
    final sb =
        StringBuffer()
          ..write(b.title)
          ..write(' by ')
          ..write(b.author);
    if (b.description != null && b.description!.trim().isNotEmpty) {
      sb.write('\n\n${b.description!.trim()}');
    }
    if (link != null && link.isNotEmpty) {
      sb.write('\n$link');
    }
    return sb.toString();
  }

  // Choose best cover URL (coverUrl field)
  // ✅ Updated parameter type to UiBook and simplified logic
  String _coverFor(UiBook b) => (b.coverUrl ?? '');

  // Decide extension using MIME; fallback to URL
  // ✅ Updated parameter type to UiBook and improved logic
  String _inferExt(UiBook b) {
    // prefer contentType from first ebook/document resource
    final ebook = b.resources.where(
      (r) => r.type == ResourceType.EBOOK || r.type == ResourceType.DOCUMENT,
    );
    if (ebook.isNotEmpty) {
      final ct = (ebook.first.contentType ?? '').toLowerCase();
      if (ct.contains('epub')) return 'epub';
      if (ct.contains('pdf')) return 'pdf';
      final url = ebook.first.contentUrl.toLowerCase();
      if (url.endsWith('.epub')) return 'epub';
      if (url.endsWith('.pdf')) return 'pdf';
    }
    final url = (b.ebookUrl ?? '').toLowerCase();
    if (url.endsWith('.epub')) return 'epub';
    if (url.endsWith('.pdf')) return 'pdf';
    return 'epub';
  }

  // ✅ Updated parameter type to UiBook
  Future<void> _openMockReader(UiBook b) async {
    // Log to reading history (best-effort)
    await ref
        .read(readingHistoryProvider.notifier)
        .logOpen(
          bookId: b.id,
          title: b.title,
          author: b.author,
          coverUrl: _coverFor(b),
          chapterIndex: 0,
          scrollProgress: 0.0,
        );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ReaderPage(
              bookTitle: b.title,
              chapters: _chapters,
              initialChapterIndex: 0,
            ),
      ),
    );
  }

  // ✅ Updated parameter type to UiBook
  Future<void> _readNow(UiBook b) async {
    // 1) Check if downloaded locally by real ID
    final store = ref.read(downloadedBooksStoreProvider);
    final entry = await store.getByBookId(b.id);
    if (!mounted) return;

    if (entry == null) {
      // Not downloaded → open mock/text reader for now
      await _openMockReader(b);
      return;
    }

    final path = entry.path;
    final isEpub = path.toLowerCase().endsWith('.epub');
    if (isEpub) {
      final theme = await ReaderPrefs.getThemeMode();
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => EpubReaderPage(
                bookId: entry.bookId,
                filePath: entry.path,
                theme: theme,
              ),
        ),
      );
    } else {
      // other file types → for now open mock reader
      await _openMockReader(b);
    }
  }

  // ✅ Updated parameter type to UiBook
  Future<void> _queueDownload(UiBook b) async {
    // resolve URL (signed endpoint if available, else resource URL)
    final repo = ref.read(bookRepositoryProvider);
    final uri = await repo.resolveDownloadUri(b.id);
    if (!mounted) return;

    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download URL not available')),
      );
      return;
    }

    final ext = _inferExt(b);

    await ref
        .read(downloadControllerProvider.notifier)
        .start(
          bookId: b.id,
          title: b.title,
          author: b.author,
          coverUrl: _coverFor(b),
          url: uri.toString(),
          ext: ext,
        );

    ref.invalidate(profileStatsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Added to Downloads')));
  }

  Future<void> _removeDownload(String bookId, String titleForToast) async {
    await ref.read(downloadedBooksManagerProvider).delete(bookId);
    ref.invalidate(isBookDownloadedProvider(bookId));
    ref.invalidate(profileStatsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$titleForToast removed from device')),
    );
  }

  Future<void> _toggleSave(String bookId, String titleForToast) async {
    await ref.read(savedBooksManagerProvider).toggle(bookId);
    ref.invalidate(isBookSavedProvider(bookId));
    ref.invalidate(profileStatsProvider);
    if (!mounted) return;

    final nowSaved = ref.read(savedBooksManagerProvider).isSaved(bookId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nowSaved
              ? '$titleForToast saved!'
              : '$titleForToast removed from Saved',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncBook = ref.watch(bookByIdProvider(widget.bookId));

    return asyncBook.when(
      loading:
          () => const Scaffold(
            appBar: _AppBarTitle(text: 'Loading…'),
            body: Center(child: CircularProgressIndicator()),
          ),
      error:
          (e, st) => const Scaffold(
            appBar: _AppBarTitle(text: 'Book'),
            body: Center(child: Text('Failed to load book')),
          ),
      data: (b) {
        final cover = _coverFor(b);
        final isSaved = ref.watch(isBookSavedProvider(b.id));
        final isDownloadedAsync = ref.watch(isBookDownloadedProvider(b.id));

        return Scaffold(
          appBar: AppBar(
            title: Text(b.title, style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.green,
            actions: [
              IconButton(
                tooltip: isSaved ? "Remove from Saved" : "Save",
                icon: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_outline,
                  color: Colors.white,
                ),
                onPressed: () => _toggleSave(b.id, b.title),
              ),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () {
                  // ✅ Simplified share logic using UiBook.ebookUrl
                  final link =
                      b.ebookUrl ??
                      (b.resources.isNotEmpty
                          ? b.resources.first.contentUrl
                          : null);
                  Share.share(
                    _buildShareText(
                      b,
                      link: (link?.isNotEmpty ?? false) ? link : null,
                    ),
                  );
                },
              ),
              const DownloadsButton(iconColor: Colors.white),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child:
                        (cover.isNotEmpty)
                            ? Image.network(
                              cover,
                              height: 200,
                              width: 140,
                              fit: BoxFit.cover,
                              errorBuilder: (context, _, __) => _coverPh(),
                            )
                            : _coverPh(),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  b.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "by ${b.author}",
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),

                const SizedBox(height: 8),

                // Basic chips (first category if any)
                if (b.categoryIds.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text('Category: ${b.categoryIds.first}'),
                        backgroundColor: Colors.green.shade50,
                      ),
                    ],
                  ),

                const SizedBox(height: 20),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _readNow(b),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text("Read Now"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: isDownloadedAsync.when(
                        data:
                            (isDownloaded) => OutlinedButton(
                              onPressed:
                                  isDownloaded
                                      ? () => _removeDownload(b.id, b.title)
                                      : () => _queueDownload(b),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(isDownloaded ? "Remove" : "Download"),
                            ),
                        loading:
                            () => OutlinedButton(
                              onPressed: null,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                        error:
                            (_, __) => OutlinedButton(
                              onPressed:
                                  () => ref.invalidate(
                                    isBookDownloadedProvider(b.id),
                                  ),
                              child: const Text("Retry"),
                            ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                const Text(
                  "Chapters",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _chapters.length,
                  itemBuilder:
                      (_, i) => Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.menu_book,
                            color: Colors.green,
                          ),
                          title: Text(_chapters[i]),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            // log mock chapter open
                            await ref
                                .read(readingHistoryProvider.notifier)
                                .logOpen(
                                  bookId: b.id,
                                  title: b.title,
                                  author: b.author,
                                  coverUrl: _coverFor(b),
                                  chapterIndex: i,
                                  scrollProgress: 0.0,
                                );
                            if (!mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => ReaderPage(
                                      bookTitle: b.title,
                                      chapters: _chapters,
                                      initialChapterIndex: i,
                                    ),
                              ),
                            );
                          },
                        ),
                      ),
                ),

                const SizedBox(height: 24),

                const Text(
                  "About This Book",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  b.description ?? "No description available",
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _coverPh() => Container(
    height: 200,
    width: 140,
    color: Colors.grey[300],
    child: const Icon(Icons.book, size: 50, color: Colors.grey),
  );
}

class _AppBarTitle extends StatelessWidget implements PreferredSizeWidget {
  final String text;
  const _AppBarTitle({required this.text});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(text, style: const TextStyle(fontSize: 16)),
      backgroundColor: Colors.green,
      actions: const [DownloadsButton(iconColor: Colors.white)],
    );
  }
}

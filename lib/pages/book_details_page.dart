import 'dart:async';
import 'dart:io'; // ADDED: For file operations (temp file)
import 'dart:typed_data'; // ADDED: For bytes data
import 'package:dio/dio.dart'; // ADDED: For making online requests (authorized)
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p; // ADDED: For path joining

// backend
import 'package:book_hub/backend/api_client.dart'; // ADDED: To get the Dio instance
import 'package:book_hub/backend/backend_providers.dart';
import 'package:book_hub/backend/book_repository.dart' show UiBook;
import 'package:book_hub/backend/models/dtos.dart';

// profile
import 'package:book_hub/features/profile/profile_stats_provider.dart';

// downloads
import 'package:book_hub/features/downloads/downloads_button.dart';
import 'package:book_hub/features/downloads/download_controller.dart';

// saved/downloaded state
import 'package:book_hub/features/books/providers/saved_downloaded_providers.dart';
import 'package:book_hub/managers/saved_books_manager.dart';
import 'package:book_hub/managers/downloaded_books_manager.dart';

// readers
import 'package:book_hub/reader/epub_reader_page.dart';
import 'package:book_hub/reader/pdf_reader_page.dart';
import 'package:book_hub/reader/reader_models.dart' as rm;
import 'package:book_hub/services/reader_prefs.dart';

// local file store
import 'package:book_hub/services/storage/downloaded_books_store.dart';

// share
import 'package:share_plus/share_plus.dart';

// auth & admin
import 'package:book_hub/features/auth/auth_provider.dart';
import 'package:book_hub/features/admin/admin_repository.dart';
import 'package:book_hub/features/books/providers/books_provider.dart';

/// Fetch a single book by id (from your real backend via the repo)
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
  // Chapters UI (single "Full Book" for now)
  List<String> _chapters = [];

  Future<bool> _confirmDelete(String title) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Delete book?'),
                content: Text('This will permanently remove "$title".'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  String _buildShareText(AppLocalizations l10n, UiBook b, {String? link}) {
    final desc = b.description.trim();
    final sb =
        StringBuffer()
          ..writeln(b.title)
          ..writeln(l10n.byAuthor(b.author));
    if ((desc.isNotEmpty)) {
      sb.write('\n\n$desc');
    }
    if (link != null && link.isNotEmpty) {
      sb.write('\n$link');
    }
    return sb.toString();
  }

  String _coverFor(UiBook b) => (b.coverUrl ?? '');

  /// Decide epub/pdf for downloads if server didn't say.
  String _inferExt(UiBook b) {
    final ebookRes = b.resources.where(
      (r) => r.type == ResourceType.EBOOK || r.type == ResourceType.DOCUMENT,
    );
    if (ebookRes.isNotEmpty) {
      final first = ebookRes.first;
      final ct = (first.contentType ?? '').toLowerCase();
      if (ct.contains('epub')) return 'epub';
      if (ct.contains('pdf')) return 'pdf';
      final url = (first.contentUrl).toLowerCase();
      if (url.endsWith('.epub')) return 'epub';
      if (url.endsWith('.pdf')) return 'pdf';
    }
    final url = (b.ebookUrl ?? '').toLowerCase();
    if (url.endsWith('.epub')) return 'epub';
    if (url.endsWith('.pdf')) return 'pdf';
    return 'epub';
  }

  // OPTIONAL: call this right after you compute `b` in the .data branch to warm Cloudinary
  Future<void> _prewarmPrimaryUrl(UiBook b) async {
    try {
      final url = _bestDownloadUrl(b);
      if (url == null) return;
      final api = ref.read(apiClientProvider);
      await api.dio.head(
        url,
        options: Options(
          // very short timeouts; if it fails we silently ignore
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          method: 'HEAD',
        ),
      );
    } catch (_) {}
  }

  // 1) REPLACED HELPER: Finds & normalizes the best download URL
  /// Returns an absolute URL for this book's primary file (epub/pdf),
  /// or null if the book has no downloadable file.
  String? _bestDownloadUrl(UiBook b) {
    final api = ref.read(apiClientProvider);
    final base = api.dio.options.baseUrl; // e.g. https://.../api/v1/

    String? normalize(String? raw) {
      final u = (raw ?? '').trim();
      if (u.isEmpty) return null;
      if (u.startsWith('http://') || u.startsWith('https://')) return u;
      // make absolute from baseUrl
      return Uri.parse(base).resolve(u).toString();
    }

    // --- DEBUG: log what the server gave us (1-2 lines per resource)
    // ignore: avoid_print
    print(
      'Book ${b.id} resources: '
      '${b.resources.map((r) => '${r.type} -> ${r.contentUrl}').join(' | ')}; '
      'ebookUrl=${b.ebookUrl}',
    );

    // 1) Prefer EBOOK/DOCUMENT if contentUrl is usable
    final preferred = b.resources.where(
      (r) =>
          (r.type == ResourceType.EBOOK || r.type == ResourceType.DOCUMENT) &&
          (r.contentUrl).trim().isNotEmpty,
    );
    for (final r in preferred) {
      final u = normalize(r.contentUrl);
      if (u != null) return u;
    }

    // 2) Fallback: FIRST resource with any non-empty contentUrl
    for (final r in b.resources) {
      final u = normalize(r.contentUrl);
      if (u != null) return u;
    }

    // 3) Legacy field on UiBook
    final u = normalize(b.ebookUrl);
    if (u != null) return u;

    // Nothing we can use
    return null;
  }
  // END REPLACED HELPER

  // 👇 REPLACED HELPER: Stream from memory with spinner
  Future<void> _openOnline(UiBook b) async {
    final l10n = AppLocalizations.of(context)!;

    final url = _bestDownloadUrl(b);
    if (url == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.downloadUrlNotAvailable)));
      return;
    }

    final api = ref.read(apiClientProvider);
    final dio = api.dio;

    // lightweight spinner while we fetch the bytes
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Stream into memory (no file write)
      final resp = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // close spinner

      final bytes = resp.data ?? const <int>[];
      final theme = await ReaderPrefs.getThemeMode();
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => EpubReaderPage(
                bookId: b.id,
                bytesData: Uint8List.fromList(
                  bytes,
                ), // 👈 open LIVE from memory
                theme: theme,
                bookTitle: b.title,
                author: b.author,
                coverUrl: _coverFor(b),
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).maybePop(); // ensure spinner is closed
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l10n.failedToLoadBook}: $e')));
    }
  }
  // 👆 END REPLACED HELPER

  Future<void> _openDownloaded(UiBook b) async {
    // capture l10n early (used below, including after awaits)
    final l10n = AppLocalizations.of(context)!;

    final store = ref.read(downloadedBooksStoreProvider);
    final entry = await store.getByBookId(b.id);
    if (!mounted) return;

    if (entry == null) {
      // If not downloaded, open online
      await _openOnline(b);
      return;
    }

    final path = entry.path;
    final lower = path.toLowerCase();

    if (lower.endsWith('.epub')) {
      final theme = await ReaderPrefs.getThemeMode();
      if (!mounted) return;
      final navigator = Navigator.of(context); // capture
      navigator.push(
        MaterialPageRoute(
          builder:
              (_) => EpubReaderPage(
                bookId: entry.bookId,
                filePath: entry.path,
                theme: theme,
                bookTitle: b.title,
                author: b.author,
                coverUrl: _coverFor(b),
              ),
        ),
      );
    } else if (lower.endsWith('.pdf')) {
      if (!mounted) return;
      final navigator = Navigator.of(context); // capture
      navigator.push(
        MaterialPageRoute(
          builder:
              (_) => PdfReaderPage(
                src: rm.ReaderSource(
                  bookId: entry.bookId,
                  title: b.title,
                  path: entry.path,
                  format: rm.ReaderFormat.pdf,
                ),
              ),
        ),
      );
    } else {
      // Unknown format - prompt a re-download with inferred ext
      await _queueDownload(l10n, b);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context); // capture
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.downloadUrlNotAvailable)),
      );
    }
  }

  // 👇 MODIFIED HELPER: Queues a download
  Future<void> _queueDownload(AppLocalizations l10n, UiBook b) async {
    // Use new helper to resolve a URL
    final url = _bestDownloadUrl(b);
    if (url == null) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context); // capture
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.downloadUrlNotAvailable)),
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
          url: url,
          ext: ext,
        );

    ref.invalidate(profileStatsProvider);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context); // capture
    messenger.showSnackBar(SnackBar(content: Text(l10n.addedToDownloads)));
  }
  // 👆 END MODIFIED HELPER

  Future<void> _removeDownload(
    AppLocalizations l10n,
    String bookId,
    String titleForToast,
  ) async {
    await ref.read(downloadedBooksManagerProvider).delete(bookId);
    ref.invalidate(isBookDownloadedProvider(bookId));
    ref.invalidate(profileStatsProvider);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context); // capture
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.bookRemovedFromDevice(titleForToast))),
    );
  }

  // ✅ PATCHED: _toggleSave to use provider state for toast and rely on provider for UI refresh
  Future<void> _toggleSave(
    AppLocalizations l10n,
    String bookId,
    String titleForToast,
  ) async {
    // Read the current state BEFORE toggling for the toast message
    // Read the bool directly (NO .value) as isBookSavedProvider(bookId) returns bool.
    final wasSaved = ref.read(isBookSavedProvider(bookId)); // bool

    await ref.read(savedBooksManagerProvider).toggle(bookId);

    // Invalidate to trigger the provider to refetch and rebuild the icon immediately
    ref.invalidate(isBookSavedProvider(bookId));
    ref.invalidate(profileStatsProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasSaved
              ? l10n.bookRemovedFromSaved(titleForToast)
              : l10n.bookSaved(titleForToast),
        ),
      ),
    );
    // No extra reads needed; provider will rebuild and fill/unfill the icon
  }
  // 👆 END PATCHED: _toggleSave

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    _chapters = [l10n.fullBook]; // single "Full book" item
    final asyncBook = ref.watch(bookByIdProvider(widget.bookId));

    return asyncBook.when(
      loading:
          () => Scaffold(
            appBar: _AppBarTitle(text: l10n.loading),
            body: const Center(child: CircularProgressIndicator()),
          ),
      error:
          (e, st) => Scaffold(
            appBar: _AppBarTitle(text: l10n.book),
            body: Center(child: Text(l10n.failedToLoadBook)),
          ),
      data: (b) {
        // fire and forget pre-warm
        Future.microtask(() => _prewarmPrimaryUrl(b));

        final cover = _coverFor(b);
        // Note: isSaved is no longer used for the icon here, only for potential non-Consumer widgets.
        // The icon uses the Consumer widget below.
        final isDownloadedAsync = ref.watch(isBookDownloadedProvider(b.id));
        final auth = ref.watch(authProvider);
        final isAdmin = (auth.role == 'ADMIN');

        // Prefer the first ebook resource for "share" if present.
        String? _shareLink() {
          final ebookRes = b.resources.where(
            (r) =>
                r.type == ResourceType.EBOOK || r.type == ResourceType.DOCUMENT,
          );
          if (ebookRes.isNotEmpty) return ebookRes.first.contentUrl;
          return b.ebookUrl;
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(b.title, style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.green,
            actions: [
              // ✅ FIX: Replaced existing Consumer logic to watch the bool directly
              Consumer(
                builder: (context, ref, _) {
                  final isSaved = ref.watch(
                    isBookSavedProvider(b.id),
                  ); // <-- bool (NO .value)

                  return IconButton(
                    tooltip:
                        isSaved
                            ? l10n.removeFromSavedTooltip
                            : l10n.saveTooltip,
                    icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_outline,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      await _toggleSave(l10n, b.id, b.title);
                    },
                  );
                },
              ),

              // 👆 END FIX: Bookmark Icon
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () {
                  final link = _shareLink();
                  Share.share(
                    _buildShareText(
                      l10n,
                      b,
                      link: (link?.isNotEmpty ?? false) ? link : null,
                    ),
                  );
                },
              ),
              const DownloadsButton(iconColor: Colors.white),
              if (isAdmin)
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_forever, color: Colors.white),
                  onPressed: () async {
                    final ok = await _confirmDelete(b.title);
                    if (!ok) return;
                    try {
                      await ref.read(adminRepositoryProvider).deleteBook(b.id);
                      ref.invalidate(booksProvider);
                      ref.invalidate(bookByIdProvider(widget.bookId));

                      if (!mounted) return;
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);

                      messenger.showSnackBar(
                        SnackBar(content: Text('"${b.title}" deleted')),
                      );
                      navigator.maybePop();
                    } catch (e) {
                      if (!mounted) return;
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(
                        SnackBar(content: Text('Failed to delete: $e')),
                      );
                    }
                  },
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  l10n.byAuthor(b.author),
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 8),

                if (b.categoryIds.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: [
                      // We only have IDs here. If you later have a category cache,
                      // resolve names and show them instead.
                      Chip(
                        label: Text('#${b.categoryIds.first}'),
                        backgroundColor: Colors.green.shade50,
                      ),
                    ],
                  ),

                const SizedBox(height: 20),

                // INSERTED: Reusable hint card (2/3)
                const SizedBox(height: 12),
                const HintCard(
                  title: 'Tip',
                  message:
                      'Reading online depends on your network and may be slow. For the smoothest experience, download the book first and read offline.',
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        //
                        // ===== 🚀 MODIFICATION HERE: Read now opens live (1/3) =====
                        //
                        onPressed: () async {
                          await _openOnline(
                            b,
                          ); // open live regardless of download state
                        },
                        //
                        // ===== 🚀 END MODIFICATION =====
                        //
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(l10n.readNow),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: isDownloadedAsync.when(
                        data:
                            (isDownloaded) => OutlinedButton(
                              onPressed:
                                  isDownloaded
                                      ? () =>
                                          _removeDownload(l10n, b.id, b.title)
                                      : () => _queueDownload(l10n, b),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                isDownloaded ? l10n.remove : l10n.download,
                              ),
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
                              child: Text(l10n.retry),
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(
                  l10n.chapters,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
                            await _openOnline(
                              b,
                            ); // open live from chapter tap too
                          },
                        ),
                      ),
                ),
                const SizedBox(height: 24),

                Text(
                  l10n.aboutThisBook,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  (b.description.trim().isNotEmpty)
                      ? b.description.trim()
                      : l10n.noDescription,
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

// INSERTED: Reusable hint card (3/3)
class HintCard extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const HintCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFEFF7EE), // soft green
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.green.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    // If you're on Flutter stable without Color.withValues, switch to withOpacity(0.85)
                    style: TextStyle(
                      color: Colors.green.shade900.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

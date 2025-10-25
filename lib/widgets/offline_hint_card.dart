import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/managers/downloaded_books_manager.dart';
import 'package:book_hub/features/books/providers/saved_downloaded_providers.dart';

class OfflineHintCard extends ConsumerStatefulWidget {
  final String bookId;
  final String? ebookUrl; // pass UiBook.ebookUrl
  final String? title;
  final String? author;
  final String? coverUrl;

  const OfflineHintCard({
    super.key,
    required this.bookId,
    required this.ebookUrl,
    this.title,
    this.author,
    this.coverUrl,
  });

  @override
  ConsumerState<OfflineHintCard> createState() => _OfflineHintCardState();
}

class _OfflineHintCardState extends ConsumerState<OfflineHintCard> {
  bool _downloading = false;

  String _guessExt(String? url) {
    final u = (url ?? '').toLowerCase();
    if (u.endsWith('.epub')) return 'epub';
    if (u.endsWith('.pdf')) return 'pdf';
    return 'epub'; // default
  }

  Future<void> _download() async {
    final url = widget.ebookUrl;
    if (url == null || url.isEmpty) return;

    setState(() => _downloading = true);
    try {
      final mgr = ref.read(downloadedBooksManagerProvider);
      await mgr.downloadFromUrl(
        bookId: widget.bookId,
        url: url,
        ext: _guessExt(url),
        title: widget.title,
        author: widget.author,
        coverUrl: widget.coverUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloaded for offline reading')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Download failed')));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDl = ref.watch(isBookDownloadedProvider(widget.bookId));

    // Hide entirely if already downloaded
    if (isDl.value == true) return const SizedBox.shrink();

    final canDownload = (widget.ebookUrl ?? '').isNotEmpty;

    return Card(
      color: const Color(0xFFFFF8E1),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Reading online can be slow on poor networks.\n'
                'For a smoother experience, download the book for offline reading.',
                style: const TextStyle(height: 1.3),
              ),
            ),
            const SizedBox(width: 12),
            if (canDownload)
              FilledButton.tonal(
                onPressed: _downloading ? null : _download,
                child:
                    _downloading
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Download'),
              ),
          ],
        ),
      ),
    );
  }
}

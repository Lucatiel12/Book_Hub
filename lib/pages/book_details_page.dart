// lib/pages/book_details_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/features/history/history_provider.dart';

import 'reader_page.dart';

// Downloads Center (icon + controller)
import 'package:book_hub/features/downloads/downloads_button.dart';
import 'package:book_hub/features/downloads/download_controller.dart';

// Saved/Downloaded state (providers + managers)
import 'package:book_hub/features/books/providers/saved_downloaded_providers.dart';
import 'package:book_hub/managers/saved_books_manager.dart';
import 'package:book_hub/managers/downloaded_books_manager.dart';

class BookDetailsPage extends ConsumerStatefulWidget {
  final String title;
  final String author;
  final String coverUrl;
  final double rating;
  final String category;
  final String description;
  final List<String>? chapters;

  const BookDetailsPage({
    super.key,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.rating,
    required this.category,
    this.description = "No description available",
    this.chapters,
  });

  @override
  ConsumerState<BookDetailsPage> createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends ConsumerState<BookDetailsPage> {
  late List<String> _chapters;

  @override
  void initState() {
    super.initState();
    _chapters =
        (widget.chapters != null && widget.chapters!.isNotEmpty)
            ? widget.chapters!
            : const ["Full Book"]; // Always show at least one chapter
  }

  void _openChapter(String chapter) {
    // Log to reading history (best-effort)
    ref
        .read(readingHistoryProvider.notifier)
        .logOpen(
          bookId:
              widget
                  .title, // if you have a stable ID, use that instead of title
          title: widget.title,
          author: widget.author,
          coverUrl: widget.coverUrl,
          chapterIndex: _chapters
              .indexOf(chapter)
              .clamp(0, _chapters.length - 1),
          scrollProgress: 0.0,
        );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ReaderPage(
              bookTitle: widget.title,
              chapters: _chapters,
              initialChapterIndex: _chapters
                  .indexOf(chapter)
                  .clamp(0, _chapters.length - 1),
            ),
      ),
    );
  }

  Future<void> _toggleSave() async {
    await ref.read(savedBooksManagerProvider).toggle(widget.title);
    // Force recompute so the icon updates instantly
    ref.invalidate(isBookSavedProvider(widget.title));

    final nowSaved = ref.read(savedBooksManagerProvider).isSaved(widget.title);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nowSaved
              ? "${widget.title} saved!"
              : "${widget.title} removed from Saved",
        ),
      ),
    );
  }

  Future<void> _queueDownload() async {
    // Add to the global Downloads Center queue (placeholder download for now)
    await ref
        .read(downloadControllerProvider.notifier)
        .start(
          bookId: widget.title, // temp id; swap to server id later
          title: widget.title,
          author: widget.author,
          coverUrl: widget.coverUrl,
          // Provide real URL + ext when backend is ready:
          // url: widget.fileUrl,
          // ext: widget.fileExt ?? 'epub',
          url: null,
          ext: 'txt',
        );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Added to Downloads')));
  }

  Future<void> _removeDownload() async {
    await ref.read(downloadedBooksManagerProvider).delete(widget.title);
    ref.invalidate(isBookDownloadedProvider(widget.title));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${widget.title} removed from device")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSaved = ref.watch(isBookSavedProvider(widget.title));
    final isDownloadedAsync = ref.watch(isBookDownloadedProvider(widget.title));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.green,
        actions: [
          // Saved toggle
          IconButton(
            tooltip: isSaved ? "Remove from Saved" : "Save",
            icon: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_outline,
              color: Colors.white,
            ),
            onPressed: _toggleSave,
          ),
          // Share (placeholder)
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              // TODO: implement share
            },
          ),
          // ✅ Downloads Center button (badge if active downloads)
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
                child: Image.network(
                  widget.coverUrl,
                  height: 200,
                  width: 140,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, _, __) => Container(
                        height: 200,
                        width: 140,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.book,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              widget.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "by ${widget.author}",
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text(
                  widget.rating.toString(),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 12),
                Chip(
                  label: Text(widget.category),
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
                    onPressed: () => _openChapter(_chapters.first),
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
                              isDownloaded ? _removeDownload : _queueDownload,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    error:
                        (_, __) => OutlinedButton(
                          onPressed:
                              () => ref.invalidate(
                                isBookDownloadedProvider(widget.title),
                              ),
                          child: const Text("Retry"),
                        ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Chapters — always visible
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
                      leading: const Icon(Icons.menu_book, color: Colors.green),
                      title: Text(_chapters[i]),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openChapter(_chapters[i]),
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
              widget.description,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

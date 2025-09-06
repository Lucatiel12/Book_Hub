// lib/pages/book_details_page.dart
import 'package:flutter/material.dart';
import 'managers/saved_books_manager.dart';
import 'managers/downloaded_books_manager.dart';
import 'reader_page.dart';

class BookDetailsPage extends StatefulWidget {
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
  State<BookDetailsPage> createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage> {
  bool isSaved = false;
  late List<String> _chapters;

  @override
  void initState() {
    super.initState();
    // Always have at least one chapter to show.
    _chapters =
        (widget.chapters != null && widget.chapters!.isNotEmpty)
            ? widget.chapters!
            : const ["Full Book"];

    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final saved = await SavedBooksManager.isBookSaved(widget.title);
    if (!mounted) return;
    setState(() => isSaved = saved);
  }

  void _openChapter(String chapter) {
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
    if (isSaved) {
      await SavedBooksManager.removeBookByTitle(widget.title);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${widget.title} removed from Saved")),
      );
      setState(() => isSaved = false);
    } else {
      await SavedBooksManager.addBook({
        "title": widget.title,
        "author": widget.author,
        "coverUrl": widget.coverUrl,
        "rating": widget.rating,
        "category": widget.category,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("${widget.title} saved!")));
      setState(() => isSaved = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            tooltip: isSaved ? "Remove from Saved" : "Save",
            icon: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_outline,
              color: Colors.white,
            ),
            onPressed: _toggleSave,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              // TODO: implement share
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover + overlay bookmark on image
            Center(
              child: Stack(
                children: [
                  ClipRRect(
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
                ],
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
                  child: OutlinedButton(
                    onPressed: () async {
                      await DownloadedBooksManager.addBook({
                        "title": widget.title,
                        "author": widget.author,
                        "coverUrl": widget.coverUrl,
                        "rating": widget.rating,
                        "category": widget.category,
                      });
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("${widget.title} downloaded!")),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text("Download"),
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

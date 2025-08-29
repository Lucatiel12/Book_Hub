import 'package:flutter/material.dart';
import '../managers/saved_books_manager.dart';
import '../managers/downloaded_books_manager.dart';

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

    // ✅ **FIX:** Initialize _chapters first with a safe fallback value.
    // This guarantees it always has a value before being used.
    _chapters =
        widget.chapters != null && widget.chapters!.isNotEmpty
            ? widget.chapters!
            : ["Full Book"];

    // Now, run the other operation that might fail.
    isSaved = SavedBooksManager.isBookSaved(widget.title);
  }

  void _toggleSave() {
    setState(() {
      if (isSaved) {
        SavedBooksManager.removeBookByTitle(widget.title);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${widget.title} removed from Saved")),
        );
      } else {
        SavedBooksManager.addBook({
          "title": widget.title,
          "author": widget.author,
          "coverUrl": widget.coverUrl,
          "rating": widget.rating,
          "category": widget.category,
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("${widget.title} saved!")));
      }
      isSaved = !isSaved;
    });
  }

  void _openChapter(String chapter) {
    // Placeholder for opening reader
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Opening $chapter...")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              // TODO: add share logic
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📕 Book Cover + Bookmark Overlay
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
                          (context, error, stackTrace) => Container(
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
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_outline,
                        color: Colors.white,
                      ),
                      onPressed: _toggleSave,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 📖 Title & Author
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

            // ⭐ Rating + Category
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

            // 🔹 Action Buttons
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
                    onPressed: () {
                      DownloadedBooksManager.addBook({
                        "title": widget.title,
                        "author": widget.author,
                        "coverUrl": widget.coverUrl,
                        "rating": widget.rating,
                        "category": widget.category,
                      });

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

            // 📚 Always show chapters
            const Text(
              "Chapters",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _chapters.length,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.menu_book, color: Colors.green),
                    title: Text(_chapters[index]),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openChapter(_chapters[index]),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // ℹ️ About This Book
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

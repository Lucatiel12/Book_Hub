import 'package:flutter/material.dart';
import 'book_details_page.dart';
import '../managers/downloaded_books_manager.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  Widget build(BuildContext context) {
    final downloadedBooks = DownloadedBooksManager.downloadedBooks;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Library"),
        backgroundColor: const Color.fromARGB(255, 17, 185, 76),
      ),
      body:
          downloadedBooks.isEmpty
              ? const Center(
                child: Text(
                  "No downloaded books yet",
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: downloadedBooks.length,
                itemBuilder: (context, index) {
                  final book = downloadedBooks[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          book["coverUrl"],
                          width: 50,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) => const Icon(
                                Icons.book,
                                size: 40,
                                color: Colors.grey,
                              ),
                        ),
                      ),
                      title: Text(
                        book["title"],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("${book["author"]} • ${book["category"]}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            DownloadedBooksManager.removeBookByTitle(
                              book["title"],
                            );
                          });
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => BookDetailsPage(
                                  title: book["title"],
                                  author: book["author"],
                                  coverUrl: book["coverUrl"],
                                  rating: book["rating"],
                                  category: book["category"],
                                  description:
                                      "This is a downloaded copy of ${book["title"]}.",
                                ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
    );
  }
}

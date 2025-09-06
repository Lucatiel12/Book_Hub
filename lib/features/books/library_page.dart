import 'package:flutter/material.dart';
import '../books/managers/downloaded_books_manager.dart';
import 'book_details_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  Future<void> _refresh() async {
    setState(() {}); // rebuild to re-fetch from prefs
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Library (Offline)"),
        backgroundColor: Colors.blueAccent,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: DownloadedBooksManager.getAll(),
          builder: (context, snapshot) {
            final items = snapshot.data ?? [];
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      "No downloads yet",
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final book = items[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        (book['coverUrl'] ?? '') as String,
                        width: 50,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => const Icon(
                              Icons.book,
                              size: 40,
                              color: Colors.grey,
                            ),
                      ),
                    ),
                    title: Text(
                      (book['title'] ?? '') as String,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "${book['author'] ?? ''} • ${book['category'] ?? ''}",
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        await DownloadedBooksManager.removeByTitle(
                          (book['title'] ?? '') as String,
                        );
                        setState(() {});
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => BookDetailsPage(
                                title: (book['title'] ?? '') as String,
                                author: (book['author'] ?? '') as String,
                                coverUrl: (book['coverUrl'] ?? '') as String,
                                rating: (book['rating'] ?? 0.0) as double,
                                category: (book['category'] ?? '') as String,
                                description:
                                    "This is a downloaded book: ${book['title']}.",
                              ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

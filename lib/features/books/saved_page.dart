import 'package:flutter/material.dart';
import '../books/managers/saved_books_manager.dart';
import '../books/book_details_page.dart';

class SavedPage extends StatefulWidget {
  const SavedPage({super.key});

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  Future<void> _refresh() async {
    // managers read from prefs each time via ensureLoaded, but we can just setState to rebuild
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Books"),
        backgroundColor: Colors.blueAccent,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: SavedBooksManager.getAll(),
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
                      "No saved books yet",
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
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await SavedBooksManager.removeBookByTitle(
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
                                    "This is a saved book: ${book['title']}.",
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

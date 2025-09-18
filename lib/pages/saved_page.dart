import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'book_details_page.dart';

// Riverpod manager
import 'package:book_hub/managers/saved_books_manager.dart';

class SavedPage extends ConsumerStatefulWidget {
  const SavedPage({super.key});

  @override
  ConsumerState<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends ConsumerState<SavedPage> {
  Future<void> _refresh() async {
    // simply rebuild to read current saved set again
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final savedMgr = ref.watch(savedBooksManagerProvider);
    final items = savedMgr.current().toList()..sort(); // titles as IDs

    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Books"),
        backgroundColor: Colors.blueAccent,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child:
            items.isEmpty
                ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(
                      child: Text(
                        "No saved books yet",
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ],
                )
                : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final title = items[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: const Icon(
                            Icons.bookmark,
                            size: 40,
                            color: Colors.green,
                          ),
                        ),
                        title: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: const Text("Saved"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await savedMgr.unsave(title);
                            setState(() {});
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("$title removed from Saved"),
                              ),
                            );
                          },
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => BookDetailsPage(
                                    title: title,
                                    author: 'Unknown',
                                    coverUrl: '', // no metadata yet
                                    rating: 0.0,
                                    category: 'Saved',
                                    description:
                                        "This is a saved book: $title.",
                                  ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
      ),
    );
  }
}

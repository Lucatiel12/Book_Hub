// lib/pages/library_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'book_details_page.dart';
import 'package:book_hub/features/downloads/download_badge.dart';

// Riverpod providers / managers
import 'package:book_hub/features/books/providers/saved_downloaded_providers.dart';
import 'package:book_hub/managers/downloaded_books_manager.dart';
import 'package:book_hub/services/storage/downloaded_books_store.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  Future<void> _refresh() async {
    // Re-fetch the downloads list
    ref.invalidate(downloadedListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(downloadedListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Library (Offline)"),
        backgroundColor: Colors.blueAccent,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: asyncList.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (e, _) => ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text('Error: $e')),
                ],
              ),
          data: (items) {
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
                final DownloadEntry e = items[index];
                final title = e.title ?? e.bookId;
                final author = e.author ?? 'Unknown';
                final cover = e.coverUrl ?? '';
                final sizeMb = (e.bytes / (1024 * 1024)).toStringAsFixed(1);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child:
                          cover.isNotEmpty
                              ? Image.network(
                                cover,
                                width: 50,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) => const Icon(
                                      Icons.book,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                              )
                              : const Icon(
                                Icons.book,
                                size: 40,
                                color: Colors.grey,
                              ),
                    ),
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // 🔹 Option A: show a progress/status badge under the author/category line
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("$author • $sizeMb MB"),
                        const SizedBox(height: 4),
                        DownloadBadge(bookId: e.bookId),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        await ref
                            .read(downloadedBooksManagerProvider)
                            .delete(e.bookId);
                        ref.invalidate(downloadedListProvider);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("$title removed from device")),
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
                                author: author,
                                coverUrl: cover,
                                rating: 0.0,
                                category: "Downloaded",
                                description:
                                    "This is a downloaded book: $title.",
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'book_details_page.dart';
import 'reader_page.dart';

import 'package:book_hub/features/history/history_provider.dart';
import 'package:book_hub/models/history_entry.dart';

class ReadingHistoryPage extends ConsumerWidget {
  const ReadingHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(readingHistoryProvider);
    final ctrl = ref.read(readingHistoryProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading History'),
        actions: [
          IconButton(
            tooltip: 'Clear All',
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      title: const Text('Clear history?'),
                      content: const Text('This will remove all recent items.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
              );
              if (ok == true) await ctrl.clearAll();
            },
          ),
        ],
      ),
      body: asyncList.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No reading history yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final HistoryEntry e = items[i];
              final dt = DateTime.fromMillisecondsSinceEpoch(e.openedAtMillis);
              final when =
                  '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
                  '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

              return Card(
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child:
                        (e.coverUrl != null && e.coverUrl!.isNotEmpty)
                            ? Image.network(
                              e.coverUrl!,
                              width: 50,
                              height: 70,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) =>
                                      const Icon(Icons.menu_book, size: 40),
                            )
                            : const Icon(Icons.menu_book, size: 40),
                  ),
                  title: Text(
                    e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${e.author} • Ch ${e.chapterIndex + 1} • ${(e.scrollProgress * 100).toStringAsFixed(0)}% • $when',
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () {
                          // Resume reading directly
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => ReaderPage(
                                    bookTitle: e.title,
                                    chapters: const [
                                      "Full Book",
                                    ], // replace with real chapters if you have them
                                    initialChapterIndex: e.chapterIndex,
                                  ),
                            ),
                          );
                        },
                        child: const Text('Resume'),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => ctrl.remove(e.bookId),
                      ),
                    ],
                  ),
                  onTap: () {
                    // Or open book details
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => BookDetailsPage(
                              title: e.title,
                              author: e.author,
                              coverUrl: e.coverUrl ?? '',
                              rating: 0.0,
                              category: 'History',
                              description: 'Last opened on $when',
                              chapters: const [
                                "Full Book",
                              ], // if you have actual chapters, pass them
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
    );
  }
}

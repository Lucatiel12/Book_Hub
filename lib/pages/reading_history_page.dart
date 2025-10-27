import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'book_details_page.dart';
import 'package:book_hub/features/history/history_provider.dart';
import 'package:book_hub/features/reading/reading_models.dart';

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
          Tooltip(
            message: 'Clear local history (offline only)',
            child: IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        title: const Text('Clear local history?'),
                        content: const Text(
                          'This removes local cached entries. Server history is unaffected.',
                        ),
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
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ctrl.refresh(),
        child: asyncList.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (e, _) => ListView(
                children: [
                  const SizedBox(height: 60),
                  Center(child: Text('Error: $e')),
                  const SizedBox(height: 12),
                  Center(
                    child: OutlinedButton(
                      onPressed: () => ctrl.refresh(),
                      child: const Text('Retry'),
                    ),
                  ),
                ],
              ),
          data: (items) {
            final isOffline = ctrl.isOffline;

            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 60),
                  Center(child: Text('No reading history yet')),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: items.length + 1, // +1 footer row
              itemBuilder: (context, i) {
                if (i == 0 && isOffline) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: _OfflineBanner(),
                  );
                }

                if (i == items.length) {
                  // footer: load more (server only)
                  if (isOffline) return const SizedBox.shrink();
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.expand_more),
                        label: const Text('Load more'),
                        onPressed: () => ctrl.loadMore(),
                      ),
                    ),
                  );
                }

                final ReadingHistoryItem e = items[i];
                return Card(
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child:
                          (e.coverImage?.isNotEmpty ?? false)
                              ? Image.network(
                                e.coverImage!, // safe because we just checked it
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
                    subtitle: Text('Last opened • ${_fmt(e.lastOpenedAt)}'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookDetailsPage(bookId: e.bookId),
                        ),
                      );
                    },
                    trailing:
                        isOffline
                            ? IconButton(
                              tooltip: 'Remove local entry',
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => ctrl.remove(e.bookId),
                            )
                            : null,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // Patched to accept nullable DateTime
  static String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.amber.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: const [
            Icon(Icons.wifi_off),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Offline mode: Showing local history cache.\nServer pagination and deletes are unavailable.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

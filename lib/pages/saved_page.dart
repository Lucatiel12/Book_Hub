import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'book_details_page.dart';

// saved manager
import 'package:book_hub/managers/saved_books_manager.dart';

// backend
import 'package:book_hub/backend/backend_providers.dart';
import 'package:book_hub/backend/book_repository.dart' show UiBook;
import 'package:book_hub/backend/models/dtos.dart' show ResourceDto;

/// Fetch a single book by id (scoped to this file for convenience)
final savedBookByIdProvider = FutureProvider.family<UiBook, String>((
  ref,
  id,
) async {
  final repo = ref.watch(bookRepositoryProvider);
  return repo.getById(id);
});

class SavedPage extends ConsumerStatefulWidget {
  const SavedPage({super.key});

  @override
  ConsumerState<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends ConsumerState<SavedPage> {
  Future<void> _refresh() async {
    // Saved set is local; just rebuild UI
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final savedMgr = ref.watch(savedBooksManagerProvider);
    // Treat saved entries as real backend IDs
    final ids = savedMgr.current().toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Books"),
        backgroundColor: Colors.green,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child:
            ids.isEmpty
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
                : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: ids.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final id = ids[index];
                    return _SavedTile(
                      bookId: id,
                      onRemove: () async {
                        await savedMgr.unsave(id);
                        if (!mounted) return;
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Removed from Saved")),
                        );
                      },
                    );
                  },
                ),
      ),
    );
  }
}

class _SavedTile extends ConsumerWidget {
  final String bookId;
  final VoidCallback onRemove;

  const _SavedTile({required this.bookId, required this.onRemove});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBook = ref.watch(savedBookByIdProvider(bookId));

    return asyncBook.when(
      loading: () => const _LoadingTile(),
      error: (e, _) => _ErrorTile(bookId: bookId, onRemove: onRemove),
      data: (b) {
        final cover = b.coverUrl ?? '';
        return Card(
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child:
                  cover.isNotEmpty
                      ? Image.network(
                        cover,
                        width: 46,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _CoverPlaceholder(),
                      )
                      : const _CoverPlaceholder(),
            ),
            title: Text(
              b.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              b.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onRemove,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookDetailsPage(bookId: b.id),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _LoadingTile extends StatelessWidget {
  const _LoadingTile();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: SizedBox(
          width: 46,
          height: 60,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        title: SizedBox(
          height: 14,
          child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0x11000000)),
          ),
        ),
        subtitle: SizedBox(
          height: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0x0F000000)),
          ),
        ),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final String bookId;
  final VoidCallback onRemove;
  const _ErrorTile({required this.bookId, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const _CoverPlaceholder(),
        title: Text(
          bookId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text("Failed to load details"),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: onRemove,
        ),
        onTap: () {
          // still allow navigate; details page will fetch
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BookDetailsPage(bookId: bookId)),
          );
        },
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.book, color: Colors.grey),
    );
  }
}

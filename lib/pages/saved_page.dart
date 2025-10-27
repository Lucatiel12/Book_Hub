import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'book_details_page.dart';

// saved manager
import 'package:book_hub/managers/saved_books_manager.dart';

// backend
import 'package:book_hub/backend/backend_providers.dart';
import 'package:book_hub/backend/book_repository.dart' show UiBook;

/// --- Book details (unchanged) ---
final savedBookByIdProvider = FutureProvider.family<UiBook, String>((
  ref,
  id,
) async {
  final repo = ref.watch(bookRepositoryProvider);
  return repo.getById(id);
});

/// --- NEW: reactive Saved IDs using a Notifier (optimistic updates) ---
class SavedIdsNotifier extends Notifier<List<String>> {
  SavedBooksManager get _mgr => ref.read(savedBooksManagerProvider);

  @override
  List<String> build() {
    final ids = _mgr.current().toList()..sort();
    return ids;
  }

  /// Optimistic remove: update UI instantly, then persist; rollback if it fails.
  Future<void> remove(String id) async {
    final prev = state;
    if (!prev.contains(id)) return;

    // optimistic UI
    state = prev.where((e) => e != id).toList();

    try {
      await _mgr.unsave(id);
    } catch (_) {
      // rollback on failure
      state = prev;
      rethrow;
    }
  }

  /// Pull-to-refresh or local resync
  void refreshNow() {
    state = _mgr.current().toList()..sort();
  }
}

final savedIdsProvider = NotifierProvider<SavedIdsNotifier, List<String>>(
  () => SavedIdsNotifier(),
);

class SavedPage extends ConsumerStatefulWidget {
  const SavedPage({super.key});

  @override
  ConsumerState<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends ConsumerState<SavedPage> {
  Future<void> _refresh() async {
    ref.read(savedIdsProvider.notifier).refreshNow();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ids = ref.watch(savedIdsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.saved), backgroundColor: Colors.green),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child:
            ids.isEmpty
                ? ListView(
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Text(
                        l10n.noSavedBooksYet,
                        style: const TextStyle(color: Colors.black54),
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
                        try {
                          await ref.read(savedIdsProvider.notifier).remove(id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.removedFromSaved)),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.errorGeneric(e.toString())),
                            ),
                          );
                        }
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
  final Future<void> Function() onRemove;

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
  final Future<void> Function() onRemove;
  const _ErrorTile({required this.bookId, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: ListTile(
        leading: const _CoverPlaceholder(),
        title: Text(
          bookId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(l10n.failedToLoadDetails),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: onRemove,
        ),
        onTap: () {
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

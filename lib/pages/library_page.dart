import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import 'book_details_page.dart';
import 'package:book_hub/features/downloads/download_badge.dart';

import 'package:book_hub/features/books/providers/saved_downloaded_providers.dart';
import 'package:book_hub/reader/open_reader.dart';
import 'package:book_hub/reader/reader_models.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  Future<void> _refresh() async {
    await ref.read(downloadedListProvider.notifier).refreshList();
  }

  Future<void> _importFromDevice() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub'],
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotOpenFile)));
        return;
      }

      // Import via notifier (adds to list optimistically)
      final entry = await ref
          .read(downloadedListProvider.notifier)
          .importLocal(sourcePath: path);

      if (!mounted) return;

      final isEpub = entry.path.toLowerCase().endsWith('.epub');
      await ReaderOpener.open(
        context,
        ReaderSource(
          bookId: entry.bookId,
          title:
              (entry.title == null || entry.title!.trim().isEmpty)
                  ? l10n.untitled
                  : entry.title!,
          author:
              (entry.author == null || entry.author!.trim().isEmpty)
                  ? l10n.unknownAuthor
                  : entry.author!,
          path: entry.path,
          format: isEpub ? ReaderFormat.epub : ReaderFormat.pdf,
        ),
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.addedToDownloads)));
    } catch (e) {
      if (!mounted) return;
      final msg =
          e.toString().toLowerCase().contains('unsupported')
              ? l10n.unsupportedFileType
              : l10n.couldNotOpenFile;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asyncList = ref.watch(downloadedListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.library), backgroundColor: Colors.green),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: asyncList.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (e, _) => ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(l10n.errorGeneric(e.toString()))),
                ],
              ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      l10n.noDownloadsYet,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final e = items[index];
                final title =
                    (e.title ?? '').trim().isEmpty ? l10n.untitled : e.title!;
                final author =
                    (e.author ?? '').trim().isEmpty
                        ? l10n.unknownAuthor
                        : e.author!;
                final cover = e.coverUrl ?? '';

                final bytes = e.bytes;
                final sizeMb = (bytes / (1024 * 1024)).toStringAsFixed(1);

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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("$author • $sizeMb MB"),
                        const SizedBox(height: 4),
                        DownloadBadge(bookId: e.bookId),
                      ],
                    ),
                    trailing: Consumer(
                      builder: (context, ref, _) {
                        final deleting = ValueNotifier<bool>(false);
                        return ValueListenableBuilder<bool>(
                          valueListenable: deleting,
                          builder: (context, isDeleting, __) {
                            return IconButton(
                              icon:
                                  isDeleting
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                              onPressed:
                                  isDeleting
                                      ? null
                                      : () async {
                                        deleting.value = true;
                                        try {
                                          await ref
                                              .read(
                                                downloadedListProvider.notifier,
                                              )
                                              .remove(e.bookId);

                                          if (!mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                l10n.bookRemovedFromDevice(
                                                  title,
                                                ),
                                              ),
                                            ),
                                          );
                                        } catch (err) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                l10n.errorGeneric(
                                                  err.toString(),
                                                ),
                                              ),
                                            ),
                                          );
                                        } finally {
                                          deleting.value = false;
                                        }
                                      },
                            );
                          },
                        );
                      },
                    ),
                    onTap: () async {
                      final path = e.path;
                      final isEpub = path.toLowerCase().endsWith('.epub');

                      final src = ReaderSource(
                        bookId: e.bookId,
                        title: title,
                        author: author,
                        path: path,
                        format: isEpub ? ReaderFormat.epub : ReaderFormat.pdf,
                      );

                      await ReaderOpener.open(context, src);
                    },
                    onLongPress: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookDetailsPage(bookId: e.bookId),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _importFromDevice,
        tooltip: AppLocalizations.of(context)!.importFromDevice,
        child: const Icon(Icons.add),
      ),
    );
  }
}

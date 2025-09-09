// lib/features/downloads/downloads_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:book_hub/features/downloads/download_controller.dart';

class DownloadsButton extends ConsumerWidget {
  final Color? iconColor;
  const DownloadsButton({super.key, this.iconColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(downloadControllerProvider);
    final activeCount =
        items
            .where(
              (d) =>
                  d.status == DownloadStatus.queued ||
                  d.status == DownloadStatus.downloading ||
                  d.status == DownloadStatus.paused,
            )
            .length;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Downloads',
          icon: const Icon(Icons.download),
          color: iconColor,
          onPressed: () => _showDownloadsSheet(context, ref),
        ),
        if (activeCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$activeCount',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

void _showDownloadsSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _DownloadsSheet(),
  );
}

class _DownloadsSheet extends ConsumerWidget {
  const _DownloadsSheet();

  String _statusText(ActiveDownload d) {
    switch (d.status) {
      case DownloadStatus.queued:
        return 'Queued…';
      case DownloadStatus.downloading:
        if (d.progress == null) return 'Downloading…';
        return 'Downloading ${(d.progress! * 100).toStringAsFixed(0)}%';
      case DownloadStatus.paused:
        if (d.progress == null) return 'Paused';
        return 'Paused at ${(d.progress! * 100).toStringAsFixed(0)}%';
      case DownloadStatus.completed:
        return 'Completed';
      case DownloadStatus.failed:
        return 'Failed${d.error != null ? ': ${d.error}' : ''}';
      case DownloadStatus.canceled:
        return 'Canceled';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.download),
                const SizedBox(width: 8),
                const Text(
                  'Downloads',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton(
                  onPressed:
                      () =>
                          ref
                              .read(downloadControllerProvider.notifier)
                              .clearCompleted(),
                  child: const Text('Clear completed'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (downloads.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'No active downloads',
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: downloads.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d = downloads[i];
                    return ListTile(
                      leading:
                          d.coverUrl != null && d.coverUrl!.isNotEmpty
                              ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  d.coverUrl!,
                                  width: 40,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) => const Icon(Icons.book),
                                ),
                              )
                              : const Icon(Icons.book),
                      title: Text(
                        d.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_statusText(d)),
                          const SizedBox(height: 6),
                          if (d.status == DownloadStatus.downloading)
                            LinearProgressIndicator(value: d.progress),
                          if (d.status == DownloadStatus.paused &&
                              d.progress != null)
                            LinearProgressIndicator(value: d.progress),
                        ],
                      ),
                      trailing: _TrailingControls(download: d),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrailingControls extends ConsumerWidget {
  const _TrailingControls({required this.download});
  final ActiveDownload download;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(downloadControllerProvider.notifier);

    switch (download.status) {
      case DownloadStatus.downloading:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Pause',
              icon: const Icon(Icons.pause),
              onPressed: () => ctrl.pause(download.bookId),
            ),
            IconButton(
              tooltip: 'Cancel',
              icon: const Icon(Icons.close),
              onPressed: () => ctrl.cancel(download.bookId),
            ),
          ],
        );
      case DownloadStatus.queued:
        return IconButton(
          tooltip: 'Cancel',
          icon: const Icon(Icons.close),
          onPressed: () => ctrl.cancel(download.bookId),
        );
      case DownloadStatus.paused:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Resume',
              icon: const Icon(Icons.play_arrow),
              onPressed: () => ctrl.resume(download.bookId),
            ),
            IconButton(
              tooltip: 'Cancel',
              icon: const Icon(Icons.close),
              onPressed: () => ctrl.cancel(download.bookId),
            ),
          ],
        );
      case DownloadStatus.failed:
        return const Icon(Icons.error, color: Colors.redAccent);
      case DownloadStatus.canceled:
        return const Icon(Icons.cancel, color: Colors.orange);
      case DownloadStatus.completed:
        return const Icon(Icons.check, color: Colors.green);
    }
  }
}

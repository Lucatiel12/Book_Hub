import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/features/downloads/download_controller.dart';

class DownloadBadge extends ConsumerWidget {
  final String bookId;
  const DownloadBadge({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadControllerProvider);
    final d =
        tasks
            .where((t) => t.bookId == bookId)
            .cast<ActiveDownload?>()
            .firstOrNull;

    if (d == null) return const SizedBox.shrink();

    String label;
    Color color;
    switch (d.status) {
      case DownloadStatus.downloading:
        final pct =
            d.progress != null
                ? (d.progress! * 100).clamp(0, 100).toStringAsFixed(0)
                : '…';
        label = 'Downloading $pct%';
        color = Colors.blue;
        break;
      case DownloadStatus.queued:
        label = 'Queued';
        color = Colors.grey;
        break;
      case DownloadStatus.paused:
        label = 'Paused';
        color = Colors.orange;
        break;
      case DownloadStatus.failed:
        label = 'Failed';
        color = Colors.red;
        break;
      case DownloadStatus.canceled:
        label = 'Canceled';
        color = Colors.redAccent;
        break;
      case DownloadStatus.completed:
        // Usually removed after 2s; no badge
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

// small extension
extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

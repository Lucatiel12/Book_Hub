import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/storage/saved_books_store.dart';
import '../../services/storage/downloaded_books_store.dart';
import '../../services/storage/reading_history_store.dart';

class ProfileStats {
  final int savedCount;
  final int downloadedCount;
  final int historyCount;
  const ProfileStats(this.savedCount, this.downloadedCount, this.historyCount);
}

final profileStatsProvider = FutureProvider<ProfileStats>((ref) async {
  final saved = await ref.read(savedBooksStoreProvider).count();
  final downloaded = await ref.read(downloadedBooksStoreProvider).count();
  final history = await ref.read(readingHistoryStoreProvider).count();
  return ProfileStats(saved, downloaded, history);
});

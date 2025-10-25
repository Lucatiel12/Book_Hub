import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/backend/api_client.dart';
import 'reading_repository.dart';

final readingRepositoryProvider = Provider<ReadingRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return ReadingRepository(api);
});

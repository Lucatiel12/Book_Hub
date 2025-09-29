import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/backend/backend_providers.dart';
import 'package:book_hub/backend/book_repository.dart';

class SubmitBookState {
  final bool isSubmitting;
  final String? errorMessage;
  const SubmitBookState({this.isSubmitting = false, this.errorMessage});

  SubmitBookState copyWith({bool? isSubmitting, String? errorMessage}) {
    return SubmitBookState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }
}

class SubmitBookController extends StateNotifier<SubmitBookState> {
  final BookRepository repo;
  SubmitBookController(this.repo) : super(const SubmitBookState());

  Future<bool> submit({
    required String title,
    required String author,
    String? description,
    String? isbn,
    String? publishedDate,
    List<String>? categoryIds,
    String? coverPath,
    required String ebookPath,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      await repo.adminCreateBook(
        title: title,
        author: author,
        description: description,
        isbn: isbn,
        publishedDate: publishedDate,
        categoryIds: categoryIds ?? const [],
        coverPath: coverPath,
        ebookPath: ebookPath,
      );
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }
}

final submitBookControllerProvider =
    StateNotifierProvider<SubmitBookController, SubmitBookState>((ref) {
      final repo = ref.watch(bookRepositoryProvider);
      return SubmitBookController(repo);
    });

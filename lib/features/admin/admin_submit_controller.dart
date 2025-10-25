// lib/features/admin/admin_submit_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/backend/api_client.dart';
import 'admin_repository.dart';

class AdminSubmitState {
  final bool loading;
  final String? error;
  final dynamic result;
  final double? uploadProgress; // 0.0 .. 1.0

  const AdminSubmitState({
    this.loading = false,
    this.error,
    this.result,
    this.uploadProgress,
  });

  AdminSubmitState copyWith({
    bool? loading,
    String? error,
    dynamic result,
    double? uploadProgress,
  }) {
    return AdminSubmitState(
      loading: loading ?? this.loading,
      error: error,
      result: result ?? this.result,
      uploadProgress: uploadProgress,
    );
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final api = ref.read(apiClientProvider);
  return AdminRepository(api);
});

final adminSubmitControllerProvider =
    StateNotifierProvider<AdminSubmitController, AdminSubmitState>((ref) {
      final repo = ref.read(adminRepositoryProvider);
      return AdminSubmitController(repo);
    });

class AdminSubmitController extends StateNotifier<AdminSubmitState> {
  final AdminRepository _repo;
  AdminSubmitController(this._repo) : super(const AdminSubmitState());

  Future<void> submit(AdminCreateBookRequest req) async {
    state = state.copyWith(
      loading: true,
      error: null,
      result: null,
      uploadProgress: 0.0,
    );
    try {
      await _repo.adminCreateBook(
        req,
        onSendProgress: (sent, total) {
          if (total > 0) {
            final p = sent / total;
            state = state.copyWith(uploadProgress: p);
          }
        },
      );
      state = state.copyWith(
        loading: false,
        result: true,
        uploadProgress: null,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
        uploadProgress: null,
      );
    }
  }
}

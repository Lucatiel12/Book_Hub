import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/backend/api_client.dart';
import 'requests_repository.dart';
import 'requests_models.dart';

/// Filters held in provider so both pages (Requests/Submissions) can share logic.
class AdminRequestFilter {
  final String? fixedType; // "LOOKUP" or "CONTRIBUTION" (null = all)
  final String status; // "PENDING" | "APPROVED" | "REJECTED"
  const AdminRequestFilter({this.fixedType, this.status = 'PENDING'});

  AdminRequestFilter copyWith({String? fixedType, String? status}) =>
      AdminRequestFilter(
        fixedType: fixedType ?? this.fixedType,
        status: status ?? this.status,
      );
}

class AdminRequestsState {
  final bool loading;
  final bool loadingMore;
  final String? error;
  final List<BookRequestResponseDto> items;
  final int page;
  final bool lastPage;
  final AdminRequestFilter filter;

  const AdminRequestsState({
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.items = const [],
    this.page = 0,
    this.lastPage = false,
    this.filter = const AdminRequestFilter(),
  });

  AdminRequestsState copyWith({
    bool? loading,
    bool? loadingMore,
    String? error,
    List<BookRequestResponseDto>? items,
    int? page,
    bool? lastPage,
    AdminRequestFilter? filter,
  }) {
    return AdminRequestsState(
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error,
      items: items ?? this.items,
      page: page ?? this.page,
      lastPage: lastPage ?? this.lastPage,
      filter: filter ?? this.filter,
    );
  }
}

final requestsRepositoryProvider = Provider<RequestsRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return RequestsRepository(api);
});

class AdminRequestsController extends StateNotifier<AdminRequestsState> {
  final RequestsRepository _repo;
  AdminRequestsController(this._repo, {String? fixedType})
    : super(
        AdminRequestsState(filter: AdminRequestFilter(fixedType: fixedType)),
      );

  Future<void> loadFirstPage() async {
    state = state.copyWith(loading: true, error: null, page: 0);
    try {
      final page = await _repo.getAdminRequests(
        page: 0,
        size: 20,
        type: state.filter.fixedType,
        status: state.filter.status,
      );
      state = state.copyWith(
        loading: false,
        items: page.content,
        page: 0,
        lastPage: page.last,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadNextPage() async {
    if (state.loadingMore || state.lastPage) return;
    state = state.copyWith(loadingMore: true, error: null);
    try {
      final next = state.page + 1;
      final page = await _repo.getAdminRequests(
        page: next,
        size: 20,
        type: state.filter.fixedType,
        status: state.filter.status,
      );
      state = state.copyWith(
        loadingMore: false,
        items: [...state.items, ...page.content],
        page: next,
        lastPage: page.last,
      );
    } catch (e) {
      state = state.copyWith(loadingMore: false, error: e.toString());
    }
  }

  Future<void> changeStatusFilter(String status) async {
    state = state.copyWith(filter: state.filter.copyWith(status: status));
    await loadFirstPage();
  }

  Future<void> approve(String id, {String? createdBookId}) async {
    // optimistic: mark item as APPROVED
    final idx = state.items.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final original = state.items[idx];
    final optimistic = [...state.items];
    optimistic[idx] = BookRequestResponseDto(
      id: original.id,
      requestType: original.requestType,
      status: BookRequestStatus.APPROVED,
      title: original.title,
      author: original.author,
      description: original.description,
      isbn: original.isbn,
      categoryIds: original.categoryIds,
      userId: original.userId,
      createdAt: original.createdAt,
      updatedAt: original.updatedAt,
      rejectionReason: null,
      createdBookId: createdBookId ?? original.createdBookId,
    );
    state = state.copyWith(items: optimistic);

    try {
      final _ = await _repo.approve(id, createdBookId: createdBookId);
    } catch (e) {
      // rollback
      final rollback = [...state.items];
      rollback[idx] = original;
      state = state.copyWith(items: rollback);
      rethrow;
    }
  }

  Future<void> reject(String id, {required String reason}) async {
    final idx = state.items.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final original = state.items[idx];
    final optimistic = [...state.items];
    optimistic[idx] = BookRequestResponseDto(
      id: original.id,
      requestType: original.requestType,
      status: BookRequestStatus.REJECTED,
      title: original.title,
      author: original.author,
      description: original.description,
      isbn: original.isbn,
      categoryIds: original.categoryIds,
      userId: original.userId,
      createdAt: original.createdAt,
      updatedAt: original.updatedAt,
      rejectionReason: reason,
      createdBookId: original.createdBookId,
    );
    state = state.copyWith(items: optimistic);

    try {
      final _ = await _repo.reject(id, reason: reason);
    } catch (e) {
      final rollback = [...state.items];
      rollback[idx] = original;
      state = state.copyWith(items: rollback);
      rethrow;
    }
  }
}

final adminRequestsControllerProvider = StateNotifierProvider.family<
  AdminRequestsController,
  AdminRequestsState,
  String?
>((ref, fixedType) {
  final repo = ref.watch(requestsRepositoryProvider);
  return AdminRequestsController(repo, fixedType: fixedType);
});

// lib/features/requests/user_requests_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/backend/api_client.dart';
import 'package:book_hub/features/admin/requests_models.dart'
    show BookRequestResponseDto; // response shape
import 'package:book_hub/features/requests/user_requests_models.dart';

// DI provider
final userRequestsRepositoryProvider = Provider<UserRequestsRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return UserRequestsRepository(api);
});

class UserRequestsRepository {
  final ApiClient _api;
  UserRequestsRepository(this._api);

  // POST /api/v1/requests/lookup
  Future<BookRequestResponseDto> lookup(BookLookupRequestDto dto) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/requests/lookup',
      data: dto.toJson(),
    );
    final root = res.data ?? const <String, dynamic>{};
    final data = (root['data'] ?? root) as Map<String, dynamic>;
    return BookRequestResponseDto.fromJson(data);
  }

  // POST /api/v1/requests/contribute
  Future<BookRequestResponseDto> contribute(
    BookContributionRequestDto dto,
  ) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/requests/contribute',
      data: dto.toJson(),
    );
    final root = res.data ?? const <String, dynamic>{};
    final data = (root['data'] ?? root) as Map<String, dynamic>;
    return BookRequestResponseDto.fromJson(data);
  }
}

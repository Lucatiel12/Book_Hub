// lib/features/admin/requests_repository.dart
import 'package:book_hub/backend/api_client.dart';
import 'package:book_hub/features/admin/requests_models.dart';

class RequestsRepository {
  final ApiClient _api;
  RequestsRepository(this._api);

  /// GET /api/v1/requests/admin
  Future<PageBookRequestResponseDto> getAdminRequests({
    int page = 0,
    int size = 20,
    String? type, // "CONTRIBUTION" | "LOOKUP"
    String? status, // "PENDING" | "APPROVED" | "REJECTED"
  }) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/requests/admin',
      queryParameters: {
        'page': page,
        'size': size,
        if (type != null && type.isNotEmpty) 'type': type,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );

    final root = res.data ?? const <String, dynamic>{};
    final pageMap = (root['data'] ?? root) as Map<String, dynamic>;
    return PageBookRequestResponseDto.fromJson(pageMap);
  }

  /// PATCH /api/v1/requests/{id}/approve
  Future<BookRequestResponseDto> approve(
    String requestId, {
    String? createdBookId,
  }) async {
    final res = await _api.request<Map<String, dynamic>>(
      'PATCH',
      '/requests/$requestId/approve',
      data: {'createdBookId': createdBookId},
    );
    final root = res.data ?? const <String, dynamic>{};
    final map = (root['data'] ?? root) as Map<String, dynamic>;
    return BookRequestResponseDto.fromJson(map);
  }

  /// PATCH /api/v1/requests/{id}/reject
  Future<BookRequestResponseDto> reject(
    String requestId, {
    required String reason,
  }) async {
    final res = await _api.request<Map<String, dynamic>>(
      'PATCH',
      '/requests/$requestId/reject',
      data: {'reason': reason},
    );
    final root = res.data ?? const <String, dynamic>{};
    final map = (root['data'] ?? root) as Map<String, dynamic>;
    return BookRequestResponseDto.fromJson(map);
  }
}

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart'; // <-- add
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/backend/api_client.dart';
import 'package:book_hub/features/admin/requests_models.dart'
    show BookRequestResponseDto;
import 'package:book_hub/features/requests/user_requests_models.dart';

final userRequestsRepositoryProvider = Provider<UserRequestsRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return UserRequestsRepository(api);
});

class UserRequestsRepository {
  final ApiClient _api;
  UserRequestsRepository(this._api);

  Future<BookRequestResponseDto> lookup(BookLookupRequestDto dto) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/requests/lookup',
      data: dto.toJson(),
    );
    final root = res.data ?? const <String, dynamic>{};
    final data = (root['data'] ?? root) as Map<String, dynamic>;
    return BookRequestResponseDto.fromJson(data);
  }

  // ✅ multipart/form-data with a JSON part named "dto"
  Future<BookRequestResponseDto> contribute(
    BookContributionRequestDto dto,
  ) async {
    final dtoJson = jsonEncode(dto.toJson());
    final form =
        FormData()
          ..files.add(
            MapEntry(
              'dto',
              MultipartFile.fromString(
                dtoJson,
                filename: 'dto.json',
                contentType: MediaType('application', 'json'), // <-- important
              ),
            ),
          );

    try {
      final res = await _api.post<Map<String, dynamic>>(
        '/requests/contribute',
        data: form,
      );
      final root = res.data ?? const <String, dynamic>{};
      final map = (root['data'] ?? root) as Map<String, dynamic>;
      return BookRequestResponseDto.fromJson(map);
    } on DioException catch (e) {
      // Log exact server message to diagnose quickly
      // ignore: avoid_print
      print('Contribute error body: ${e.response?.data}');
      final body = e.response?.data;
      final msg =
          body is Map
              ? (body['message'] ?? body['error'] ?? body).toString()
              : (e.message ?? 'Bad request');
      throw Exception('Submit failed: $msg');
    }
  }
}

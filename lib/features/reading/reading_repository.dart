import 'package:book_hub/backend/api_client.dart';
import 'package:book_hub/features/reading/reading_models.dart'
    as rm; // 👈 alias
import 'package:dio/dio.dart';

class ReadingRepository {
  final ApiClient _api;
  ReadingRepository(this._api);

  Future<String?> logHistory(String bookId) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/history',
      data: {'bookId': bookId},
      options: Options(contentType: Headers.jsonContentType),
    );
    return (res.data?['data']) as String?;
  }

  Future<rm.ReadingProgressDto?> getProgress(String bookId) async {
    final res = await _api.get<Map<String, dynamic>>('/progress/$bookId');
    final data = res.data?['data'] as Map<String, dynamic>?;
    if (data == null) return null;
    return rm.ReadingProgressDto.fromJson(data);
  }

  Future<rm.ReadingProgressDto?> saveProgress(
    String bookId, {
    required double percent,
    Map<String, dynamic>? locator,
    String? format,
  }) async {
    final payload = <String, dynamic>{
      if (format != null) 'format': format,
      if (locator != null) 'location': locator, // per swagger
      'percent': percent,
    };

    final res = await _api.put<Map<String, dynamic>>(
      '/progress/$bookId',
      data: payload,
      options: Options(contentType: Headers.jsonContentType),
    );
    final data = res.data?['data'] as Map<String, dynamic>?;
    return data == null ? null : rm.ReadingProgressDto.fromJson(data);
  }

  Future<rm.PageResponse<rm.ReadingHistoryItem>> getHistory({
    int page = 0,
    int size = 20,
    String? sort,
  }) async {
    final qp = <String, dynamic>{'page': page, 'size': size};
    if (sort != null && sort.isNotEmpty) qp['sort'] = sort;

    final res = await _api.get<Map<String, dynamic>>(
      '/history',
      queryParameters: qp,
    );
    final data = res.data?['data'] as Map<String, dynamic>?;

    if (data == null) {
      return rm.PageResponse<rm.ReadingHistoryItem>(
        totalElements: 0,
        totalPages: 0,
        size: size,
        number: page,
        numberOfElements: 0,
        last: true,
        first: page == 0,
        empty: true,
        content: const [],
      );
    }

    return rm.PageResponse.fromJson<rm.ReadingHistoryItem>(
      data,
      (m) => rm.ReadingHistoryItem.fromJson(m),
    );
  }
}

// lib/backend/api_client.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:book_hub/features/auth/auth_provider.dart';
import 'models/dtos.dart';

// -------------------- Tokens & callbacks --------------------
typedef GetAccessToken = Future<String?> Function();
typedef GetRefreshToken = Future<String?> Function();
typedef SaveTokens = Future<void> Function(AuthTokens);
typedef ClearTokens = Future<void> Function();

class AuthTokens {
  final String accessToken;
  final String? refreshToken;
  AuthTokens(this.accessToken, this.refreshToken);
}

// -------------------- ApiClient --------------------
class ApiClient {
  final Dio _dio;
  final GetAccessToken getAccessToken;
  final GetRefreshToken getRefreshToken;
  final SaveTokens saveTokens;
  final ClearTokens clearTokens;

  /// e.g. '/api/v1'
  final String apiPrefix;

  /// e.g. '/api/v1/auth/refresh'
  final String refreshPath;

  Dio get dio => _dio;

  ApiClient({
    required String baseUrl,
    required this.getAccessToken,
    required this.getRefreshToken,
    required this.saveTokens,
    required this.clearTokens,
    this.apiPrefix = '',
    this.refreshPath = '/auth/refresh',
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           headers: {'Accept': 'application/json'},
           // ⬇️ Give cold/slow servers more room
           connectTimeout: const Duration(seconds: 20),
           receiveTimeout: const Duration(seconds: 45),
           sendTimeout: const Duration(seconds: 45),
         ),
       ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) async {
          // attach bearer except for auth endpoints
          final isAuthCall = o.uri.path.contains('/auth/');
          if (!isAuthCall) {
            final tok = await getAccessToken();
            if (tok != null && tok.isNotEmpty) {
              o.headers['Authorization'] = 'Bearer $tok';
            }
          }
          h.next(o);
        },
        onError: (e, h) async {
          if (e.response?.statusCode == 401) {
            // avoid looping on refresh
            if (e.requestOptions.path == refreshPath) {
              await clearTokens();
              return h.next(e);
            }

            final rt = await getRefreshToken();
            if (rt != null && rt.isNotEmpty) {
              try {
                final res = await _dio.post(
                  refreshPath,
                  data: {'refreshToken': rt},
                  options: Options(headers: {'Authorization': null}),
                );

                // { status, message, data: { accessToken, refreshToken, user } } or { accessToken, ... }
                String? newAccess;
                String? newRefresh;
                final body = res.data;
                if (body is Map<String, dynamic>) {
                  final data = (body['data'] ?? body) as Map<String, dynamic>;
                  newAccess =
                      (data['accessToken'] ?? data['jwtToken'])?.toString();
                  newRefresh = data['refreshToken']?.toString();
                }

                if (newAccess != null && newAccess.isNotEmpty) {
                  await saveTokens(AuthTokens(newAccess, newRefresh));

                  // retry original
                  final req = e.requestOptions;
                  req.headers['Authorization'] = 'Bearer $newAccess';
                  final response = await _dio.fetch(req);
                  return h.resolve(response);
                }
              } catch (_) {
                await clearTokens();
              }
            } else {
              await clearTokens();
            }
          }
          h.next(e);
        },
      ),
    );

    // Add request/response logging
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: false,
        responseHeader: true,
        responseBody: false, // set true if you want full JSON dumps
        error: true,
      ),
    );
  }

  // -------------------- small retry helper --------------------
  Future<R> _withRetry<R>(Future<R> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      final t = e.type;
      if (t == DioExceptionType.connectionTimeout ||
          t == DioExceptionType.receiveTimeout ||
          t == DioExceptionType.sendTimeout) {
        // one quick retry
        return await fn();
      }
      rethrow;
    }
  }

  // -------------------- HTTP helpers --------------------
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get<T>(
      _full(path),
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.post<T>(
      _full(path),
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Multipart POST with long timeouts + progress callback.
  Future<Response<T>> postMultipart<T>(
    String path, {
    required FormData data,
    Duration sendTimeout = const Duration(minutes: 3),
    Duration receiveTimeout = const Duration(minutes: 3),
    ProgressCallback? onSendProgress,
  }) {
    return _dio.post<T>(
      _full(path),
      data: data,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: sendTimeout,
        receiveTimeout: receiveTimeout,
      ),
      onSendProgress: onSendProgress,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.put<T>(
      _full(path),
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.delete<T>(
      _full(path),
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> request<T>(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.request<T>(
      _full(path),
      data: data,
      queryParameters: queryParameters,
      options: (options ?? Options()).copyWith(method: method),
    );
  }

  String _full(String path) {
    if (apiPrefix.isEmpty) return path;
    return path.startsWith('$apiPrefix/')
        ? path
        : path.startsWith('/')
        ? '$apiPrefix$path'
        : '$apiPrefix/$path';
  }

  // ---------- Domain helpers (exactly per your Swagger) ----------

  /// GET /api/v1/books
  /// Response: { status, message, data: PageBookResponseDTO }
  Future<PageBookResponseDto> getBooks({
    String? query, // optional/no-op if backend ignores
    String? categoryId, // optional/no-op if backend ignores
    int page = 0,
    int size = 20,
  }) async {
    return _withRetry(() async {
      final res = await get<Map<String, dynamic>>(
        '/books',
        queryParameters: {
          'page': page,
          'size': size,
          if (query != null && query.isNotEmpty) 'q': query,
          if (categoryId != null && categoryId.isNotEmpty)
            'categoryId': categoryId,
        },
      );

      // unwrap { data: { content, number, totalPages, ... } }
      final map = res.data ?? const <String, dynamic>{};
      final pageMap = (map['data'] ?? map) as Map<String, dynamic>;
      return PageBookResponseDto.fromJson(pageMap);
    });
  }

  /// GET /api/v1/books/{id}
  /// Response: { status, message, data: BookResponseDTO }
  Future<BookResponseDto> getBook(String id) async {
    return _withRetry(() async {
      final res = await get<Map<String, dynamic>>('/books/$id');
      final map = res.data ?? const <String, dynamic>{};
      final data = (map['data'] ?? map) as Map<String, dynamic>;
      return BookResponseDto.fromJson(data);
    });
  }

  /// DELETE /api/v1/books/{bookId}
  Future<void> deleteBook(String bookId) async {
    await _withRetry(() async {
      // server returns {status,message,data} (data is usually a string)
      await delete<Map<String, dynamic>>('/books/$bookId');
    });
  }

  // Quick one-off raw fetcher to debug the book payload shape
  Future<Map<String, dynamic>> getBookRaw(String id) async {
    final res = await get<Map<String, dynamic>>('/books/$id');
    // unwrap common { data: {...} } envelopes
    final root = res.data ?? const <String, dynamic>{};
    final data =
        (root['data'] is Map<String, dynamic>)
            ? (root['data'] as Map<String, dynamic>)
            : root;
    return data.cast<String, dynamic>();
  }

  /// GET /api/v1/categories
  /// Swagger: PageCategoryDTO (sometimes wrapped as {status,message,data} elsewhere).
  /// We return just the list of categories.
  Future<List<CategoryDto>> getCategories({
    int page = 0,
    int size = 100,
  }) async {
    return _withRetry(() async {
      final res = await get<Map<String, dynamic>>(
        '/categories',
        queryParameters: {'page': page, 'size': size},
      );

      final root = res.data ?? const <String, dynamic>{};

      // If wrapped, unwrap; otherwise treat as the page object itself.
      final pageObj =
          (root['data'] is Map<String, dynamic>) ? root['data'] : root;

      final list = (pageObj['content'] as List<dynamic>? ?? const []);
      return list
          .map((e) => CategoryDto.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// POST /api/v1/categories
  /// Body: { "name": "Fantasy" }
  /// Response: either { status, message, data: CategoryDTO } or CategoryDTO
  Future<CategoryDto> createCategory(String name) async {
    return _withRetry(() async {
      final res = await post<Map<String, dynamic>>(
        '/categories',
        data: {'name': name},
      );

      final root = res.data ?? const <String, dynamic>{};
      final map = (root['data'] ?? root) as Map<String, dynamic>;
      return CategoryDto.fromJson(map);
    });
  }

  // 2) NEW METHODS ADDED
  /// GET /api/v1/history
  Future<PageReadingHistoryResponseDto> getReadingHistory({
    int page = 0,
    int size = 10,
  }) async {
    return _withRetry(() async {
      final res = await get<Map<String, dynamic>>(
        '/history',
        queryParameters: {'page': page, 'size': size},
      );
      final root = res.data ?? const <String, dynamic>{};
      final map = (root['data'] ?? root) as Map<String, dynamic>;
      return PageReadingHistoryResponseDto.fromJson(map);
    });
  }

  /// POST /api/v1/history  body: { "bookId": "..." }
  Future<void> logHistory(String bookId) async {
    await _withRetry(() async {
      await post<Map<String, dynamic>>('/history', data: {'bookId': bookId});
    });
  }

  /// GET /api/v1/progress/{bookId}
  Future<ReadingProgressDto?> getProgress(String bookId) async {
    return _withRetry(() async {
      final res = await get<Map<String, dynamic>>('/progress/$bookId');
      final root = res.data ?? const <String, dynamic>{};
      final data = (root['data'] ?? root);
      if (data is Map<String, dynamic>) {
        return ReadingProgressDto.fromJson(data);
      }
      return null;
    });
  }

  /// PUT /api/v1/progress/{bookId}
  Future<ReadingProgressDto> updateProgress(
    String bookId, {
    required ReadingProgressDto progress,
  }) async {
    return _withRetry(() async {
      final res = await put<Map<String, dynamic>>(
        '/progress/$bookId',
        data: progress.toJson(),
      );
      final root = res.data ?? const <String, dynamic>{};
      final data = (root['data'] ?? root) as Map<String, dynamic>;
      return ReadingProgressDto.fromJson(data);
    });
  }
}

// -------------------- Providers --------------------

final apiBaseUrlProvider = Provider<String>((ref) {
  return const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://bookhub-86lf.onrender.com',
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);

  // NOTE: do not capture authState into a local variable.
  final authNotifier = ref.read(authProvider.notifier);

  return ApiClient(
    baseUrl: baseUrl,
    apiPrefix: '/api/v1',
    refreshPath: '/api/v1/auth/refresh',

    // ⬇️ Always read the *current* state when a request starts
    getAccessToken: () async => ref.read(authProvider).token,
    getRefreshToken: () async => ref.read(authProvider).refreshToken,

    saveTokens:
        (t) async => authNotifier.saveTokens(
          access: t.accessToken,
          refresh: t.refreshToken,
        ),
    clearTokens: () async => authNotifier.logout(),
  );
});

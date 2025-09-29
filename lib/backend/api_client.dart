import 'package:dio/dio.dart';
import 'models/dtos.dart';

typedef GetAccessToken = Future<String?> Function();
typedef GetRefreshToken = Future<String?> Function();
typedef SaveTokens = Future<void> Function(AuthTokens);
typedef ClearTokens = Future<void> Function();

class AuthTokens {
  final String accessToken;
  final String? refreshToken;
  AuthTokens(this.accessToken, this.refreshToken);
}

/// A Dio-based API client that handles automatic token injection and refresh.
///
/// ## Example
///
/// If your backend paths are actually under `/api/v1`, instantiate ApiClient like so:
///
/// ```dart
/// ApiClient(
///   baseUrl: '[https://bookhub-86lf.onrender.com](https://bookhub-86lf.onrender.com)',
///   getAccessToken: ..., // your function to get the stored access token
///   getRefreshToken: ..., // your function to get the stored refresh token
///   saveTokens: ..., // your function to save new tokens
///   clearTokens: ..., // your function to clear tokens on failure/logout
///   apiPrefix: '/api/v1',
///   refreshPath: '/api/v1/auth/refresh',
/// )
/// ```
class ApiClient {
  final Dio _dio;
  final GetAccessToken getAccessToken;
  final GetRefreshToken getRefreshToken;
  final SaveTokens saveTokens;
  final ClearTokens clearTokens;

  /// If your backend uses a prefix like `/api/v1`, set this accordingly.
  final String apiPrefix;

  /// The full path where the backend exposes the token refresh endpoint.
  /// Example: `/auth/refresh` or `/api/v1/auth/refresh`
  final String refreshPath;

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
           connectTimeout: const Duration(seconds: 10),
           receiveTimeout: const Duration(seconds: 10),
         ),
       ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) async {
          // Attach access token to non-auth calls
          final path = o.uri.path; // absolute path
          final isAuthCall = path.contains('/auth/');
          if (!isAuthCall) {
            final tok = await getAccessToken();
            if (tok != null && tok.isNotEmpty) {
              o.headers['Authorization'] = 'Bearer $tok';
            }
          }
          h.next(o);
        },
        onError: (e, h) async {
          // Try to refresh the token once on 401 Unauthorized error
          if (e.response?.statusCode == 401) {
            // Prevent a refresh loop if the refresh endpoint itself fails
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
                  // Ensure no stale auth header is sent with the refresh request
                  options: Options(headers: {'Authorization': null}),
                );

                // Flexible parsing to support responses like { "data": { ... } } or { ... }
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

                  // Retry the original request with the new token
                  final req = e.requestOptions;
                  req.headers['Authorization'] = 'Bearer $newAccess';
                  final response = await _dio.fetch(req);
                  return h.resolve(response);
                }
              } catch (_) {
                // If refresh fails, clear tokens and let the original error proceed
                await clearTokens();
              }
            } else {
              // No refresh token available, so clear any stale tokens
              await clearTokens();
            }
          }
          h.next(e);
        },
      ),
    );
  }

  // ---------------------------
  // HTTP verb helper methods
  // ---------------------------
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

  /// Prepends the `apiPrefix` to the path if it's not already there.
  String _full(String path) {
    if (apiPrefix.isEmpty) return path;
    // Avoid double-prefixing if the caller already provided a full path
    return path.startsWith('$apiPrefix/')
        ? path
        : path.startsWith('/')
        ? '$apiPrefix$path'
        : '$apiPrefix/$path';
  }

  // ---------- Books ----------
  Future<PageBookResponseDto> getBooks({
    String? query,
    String? categoryId,
    int page = 0,
    int size = 20,
  }) async {
    final res = await get<Map<String, dynamic>>(
      '/books',
      queryParameters: {
        if (query != null && query.isNotEmpty) 'q': query,
        if (categoryId != null && categoryId.isNotEmpty)
          'categoryId': categoryId,
        'page': page,
        'size': size,
      },
    );
    final data = res.data?['data'] as Map<String, dynamic>;
    return PageBookResponseDto.fromJson(data);
  }

  Future<BookResponseDto> getBook(String id) async {
    final res = await get<Map<String, dynamic>>('/books/$id');
    final data = res.data?['data'] as Map<String, dynamic>;
    return BookResponseDto.fromJson(data);
  }

  // ---------- Categories ----------
  Future<List<CategoryDto>> getCategories() async {
    final res = await get<Map<String, dynamic>>('/categories');
    final list = (res.data?['data'] as List<dynamic>? ?? const []);
    return list
        .map((e) => CategoryDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// lib/features/auth/auth_provider.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:book_hub/debug/debug_jwt.dart'; // ✅ Correctly imported

// ✅ Import the new api_client.dart to use the base URL provider
import 'package:book_hub/backend/api_client.dart';

// ... (AuthState class is unchanged) ...
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? errorMessage;

  final String? token; // accessToken (JWT)
  final String? refreshToken; // refreshToken

  final String? email;
  final String? firstName;
  final String? lastName;
  final String? role;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.errorMessage,
    this.token,
    this.refreshToken,
    this.email,
    this.firstName,
    this.lastName,
    this.role,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? errorMessage,
    String? token,
    String? refreshToken,
    String? email,
    String? firstName,
    String? lastName,
    String? role,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      errorMessage: errorMessage,
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  // ✅ Dio client is now passed in, not created here.
  final Dio _dio;
  final _storage = const FlutterSecureStorage();

  // ✅ Updated constructor
  AuthNotifier(this._dio) : super(const AuthState()) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opts, handler) {
          final path = opts.uri.path;
          final isAuthPath = path.contains('/auth/');

          if (!isAuthPath) {
          } else {
            opts.headers.remove('Authorization');
          }
          handler.next(opts);
        },
      ),
    );
  }
  // ... (saveTokens, clearTokens are unchanged) ...
  Future<void> saveTokens({required String access, String? refresh}) async {
    await _storage.write(key: 'auth_token', value: access);
    if (refresh != null) {
      await _storage.write(key: 'refresh_token', value: refresh);
    }
    state = state.copyWith(
      token: access,
      refreshToken: refresh ?? state.refreshToken,
      isAuthenticated: true,
    );
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'refresh_token');
    state = state.copyWith(
      token: null,
      refreshToken: null,
      isAuthenticated: false,
    );
  }

  /// Auto login (restore tokens & profile from secure storage)
  Future<void> tryAutoLogin() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final token = await _storage.read(key: 'auth_token');
    final refresh = await _storage.read(key: 'refresh_token');
    final email = await _storage.read(key: 'email');
    final firstName = await _storage.read(key: 'firstName');
    final lastName = await _storage.read(key: 'lastName');
    final role = await _storage.read(key: 'role');

    if (token != null && token.isNotEmpty) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        token: token,
        refreshToken: refresh,
        email: email,
        firstName: firstName,
        lastName: lastName,
        role: role,
      );
      // 👇 ADDED HERE
      debugPrintJwtClaims(token);
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _dio.post(
        "/auth/login",
        data: {"email": email, "password": password},
        options: Options(extra: {'noAuth': true}),
      );

      final access = _extractAccessToken(res.data);
      final refresh = _extractRefreshToken(res.data);
      final user = _extractUser(res.data);

      if (access != null && user != null) {
        await _storage.write(key: 'auth_token', value: access);
        if (refresh != null) {
          await _storage.write(key: 'refresh_token', value: refresh);
        }
        await _storage.write(key: 'email', value: user['email'] ?? '');
        await _storage.write(key: 'firstName', value: user['firstName'] ?? '');
        await _storage.write(key: 'lastName', value: user['lastName'] ?? '');
        await _storage.write(
          key: 'role',
          value: user['role']?.toString() ?? '',
        );

        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          token: access,
          refreshToken: refresh,
          email: user['email']?.toString(),
          firstName: user['firstName']?.toString(),
          lastName: user['lastName']?.toString(),
          role: user['role']?.toString(),
        );

        // 👇 ADDED HERE
        debugPrintJwtClaims(access);
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: "No token or user info received from server",
        );
      }
    } on DioException catch (e) {
      // ignore: avoid_print
      print(
        'Login error: status=${e.response?.statusCode} body=${e.response?.data}',
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage: _humanizeDioError(e),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Unexpected error: $e",
      );
    }
  }

  // ... (Rest of the class: register, refresh, helpers, etc. are unchanged) ...
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _dio.post(
        "/auth/register",
        data: {
          // RegisterRequestDTO — no confirmPassword
          "firstName": firstName,
          "lastName": lastName,
          "email": email,
          "password": password,
        },
        options: Options(extra: {'noAuth': true}),
      );

      final access = _extractAccessToken(res.data);
      final refresh = _extractRefreshToken(res.data);
      final user = _extractUser(res.data);

      if (access != null && user != null) {
        await _storage.write(key: 'auth_token', value: access);
        if (refresh != null) {
          await _storage.write(key: 'refresh_token', value: refresh);
        }
        await _storage.write(key: 'email', value: user['email'] ?? '');
        await _storage.write(key: 'firstName', value: user['firstName'] ?? '');
        await _storage.write(key: 'lastName', value: user['lastName'] ?? '');
        await _storage.write(
          key: 'role',
          value: user['role']?.toString() ?? '',
        );

        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          token: access,
          refreshToken: refresh,
          email: user['email']?.toString(),
          firstName: user['firstName']?.toString(),
          lastName: user['lastName']?.toString(),
          role: user['role']?.toString(),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: "No token or user info received from server",
        );
      }
    } on DioException catch (e) {
      // ignore: avoid_print
      print(
        'Register error: status=${e.response?.statusCode} body=${e.response?.data}',
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage: _humanizeDioError(e),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Unexpected error: $e",
      );
    }
  }

  /// Explicit refresh using RefreshTokenRequestDTO { refreshToken }
  Future<bool> refresh() async {
    final currentRefresh =
        state.refreshToken ?? await _storage.read(key: 'refresh_token');
    if (currentRefresh == null || currentRefresh.isEmpty) return false;
    try {
      final res = await _dio.post(
        "/auth/refresh",
        data: {"refreshToken": currentRefresh},
        options: Options(extra: {'noAuth': true}),
      );
      final access = _extractAccessToken(res.data);
      final refresh = _extractRefreshToken(res.data) ?? currentRefresh;
      if (access == null) return false;
      await saveTokens(access: access, refresh: refresh);
      return true;
    } on DioException catch (e) {
      // ignore: avoid_print
      print(
        'Refresh error: status=${e.response?.statusCode} body=${e.response?.data}',
      );
      await clearTokens();
      return false;
    }
  }

  void clearError() => state = state.copyWith(errorMessage: null);

  // ---------------- helpers ----------------

  // Responses are { "data": { accessToken, refreshToken, user: {...} }, "error": null }
  String? _extractAccessToken(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final data = responseData['data'];
      if (data is Map<String, dynamic>) {
        return data['accessToken'] as String?;
      }
    }
    return null;
  }

  String? _extractRefreshToken(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final data = responseData['data'];
      if (data is Map<String, dynamic>) {
        return data['refreshToken'] as String?;
      }
    }
    return null;
  }

  Map<String, dynamic>? _extractUser(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final data = responseData['data'];
      if (data is Map<String, dynamic>) {
        final u = data['user'];
        if (u is Map<String, dynamic>) return u;
      }
    }
    return null;
  }

  String _humanizeDioError(DioException e) {
    final code = e.response?.statusCode ?? 0;
    final d = e.response?.data;

    // special-cases first
    if (code == 403) {
      return "Registration is disabled for this server account. Please contact an admin or use an existing account.";
    }

    if (d is Map<String, dynamic>) {
      final err = d['error'];
      if (err is Map<String, dynamic>) {
        return err['message']?.toString() ??
            err['code']?.toString() ??
            "Request failed";
      }
      return d['message']?.toString() ??
          d['error']?.toString() ??
          "Request failed";
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return "Connection timeout. Please check your internet.";
    }
    if (e.type == DioExceptionType.connectionError) {
      return "No internet connection.";
    }
    return "An unexpected error occurred.";
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    state = const AuthState();
  }
}

// ... (Provider definition is unchanged) ...
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  // Use the single source of truth for the base URL
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final authDio = Dio(
    BaseOptions(
      // The Dio client for auth calls needs the full path including the prefix
      baseUrl: "$baseUrl/api/v1",
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );
  return AuthNotifier(authDio);
});

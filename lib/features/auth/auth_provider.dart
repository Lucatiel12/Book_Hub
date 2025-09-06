import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? errorMessage;
  final String? token;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? role;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.errorMessage,
    this.token,
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
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "https://bookhub-86lf.onrender.com",
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  final _storage = const FlutterSecureStorage();

  AuthNotifier() : super(AuthState());

  // ✅ Auto login (restore token & user info from secure storage)
  Future<void> tryAutoLogin() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final token = await _storage.read(key: 'auth_token');
    final email = await _storage.read(key: 'email');
    final firstName = await _storage.read(key: 'firstName');
    final lastName = await _storage.read(key: 'lastName');
    final role = await _storage.read(key: 'role');

    if (token != null) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        token: token,
        email: email,
        firstName: firstName,
        lastName: lastName,
        role: role,
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _dio.post(
        "/api/auth/login",
        data: {"email": email, "password": password},
      );

      print('Raw Server Response Data (Login): ${response.data}');

      final token = _extractToken(response.data);
      final user = _extractUser(response.data);

      if (token != null && user != null) {
        // ✅ Save to storage
        await _storage.write(key: 'auth_token', value: token);
        await _storage.write(key: 'email', value: user['email']);
        await _storage.write(key: 'firstName', value: user['firstName']);
        await _storage.write(key: 'lastName', value: user['lastName']);
        await _storage.write(key: 'role', value: user['role']);

        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          token: token,
          email: user['email'],
          firstName: user['firstName'],
          lastName: user['lastName'],
          role: user['role'],
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: "No token or user info received from server",
        );
      }
    } on DioException catch (e) {
      String errorMessage;

      if (e.response != null) {
        errorMessage =
            _extractErrorMessage(e.response?.data) ??
            "Login failed. Please try again.";
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMessage = "Connection timeout. Please check your internet.";
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = "No internet connection.";
      } else {
        errorMessage = "An unexpected error occurred.";
      }

      state = state.copyWith(isLoading: false, errorMessage: errorMessage);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "An unexpected error occurred: ${e.toString()}",
      );
    }
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _dio.post(
        "/api/auth/register",
        data: {
          "firstName": firstName,
          "lastName": lastName,
          "email": email,
          "password": password,
          "confirmPassword": password,
        },
      );

      print('Raw Server Response Data (Register): ${response.data}');

      final token = _extractToken(response.data);
      final user = _extractUser(response.data);

      if (token != null && user != null) {
        // ✅ Save to storage
        await _storage.write(key: 'auth_token', value: token);
        await _storage.write(key: 'email', value: user['email']);
        await _storage.write(key: 'firstName', value: user['firstName']);
        await _storage.write(key: 'lastName', value: user['lastName']);
        await _storage.write(key: 'role', value: user['role']);

        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          token: token,
          email: user['email'],
          firstName: user['firstName'],
          lastName: user['lastName'],
          role: user['role'],
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: "No token or user info received from server",
        );
      }
    } on DioException catch (e) {
      String errorMessage;

      if (e.response != null) {
        errorMessage =
            _extractErrorMessage(e.response?.data) ??
            "Registration failed. Please try again.";
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMessage = "Connection timeout. Please check your internet.";
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = "No internet connection.";
      } else {
        errorMessage = "An unexpected error occurred.";
      }

      state = state.copyWith(isLoading: false, errorMessage: errorMessage);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "An unexpected error occurred: ${e.toString()}",
      );
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  String? _extractToken(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final data = responseData['data'];
      if (data is Map<String, dynamic>) {
        return data['jwtToken'] as String?;
      }
    }
    return null;
  }

  Map<String, dynamic>? _extractUser(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final data = responseData['data'];
      if (data is Map<String, dynamic>) {
        return data['user'] as Map<String, dynamic>?;
      }
    }
    return null;
  }

  String? _extractErrorMessage(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      return responseData['message']?.toString() ??
          responseData['error']?.toString();
    } else if (responseData is String) {
      return responseData;
    }
    return null;
  }

  Future<void> logout() async {
    await _storage.deleteAll(); // ✅ clear everything
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

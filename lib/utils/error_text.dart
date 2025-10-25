// lib/utils/error_text.dart
import 'dart:io';
import 'package:dio/dio.dart';

/// Returns a short, user-friendly error message for display in UI.
String friendlyError(Object error) {
  // Offline or DNS failure
  if (error is SocketException) {
    return 'No internet connection. Please check your network.';
  }

  if (error is DioException) {
    // Connection / timeout types
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'No internet connection. Please check your network.';
    }

    // HTTP status codes
    final code = error.response?.statusCode ?? 0;
    if (code >= 500) return 'Server is unavailable right now.';
    if (code == 404) return 'Resource not found.';
    if (code == 401) return 'Authentication required.';
    if (code == 403) return 'Access denied.';

    if (error.type == DioExceptionType.cancel) {
      return 'Request was cancelled.';
    }
  }

  // Fallback generic
  return 'Something went wrong. Please try again later.';
}

// lib/backend/backend_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'book_repository.dart';
import 'package:book_hub/features/auth/auth_provider.dart';

// Base URL ONLY (no /api/v1 here)
final backendBaseUrlProvider = Provider<String>(
  (_) => 'https://bookhub-86lf.onrender.com',
);

final getAccessTokenProvider = Provider<GetAccessToken>((ref) {
  return () async => ref.read(authProvider).token;
});
final getRefreshTokenProvider = Provider<GetRefreshToken>((ref) {
  return () async => ref.read(authProvider).refreshToken;
});
final saveTokensProvider = Provider<SaveTokens>((ref) {
  return (t) async => ref
      .read(authProvider.notifier)
      .saveTokens(access: t.accessToken, refresh: t.refreshToken);
});
final clearTokensProvider = Provider<ClearTokens>((ref) {
  return () async => ref.read(authProvider.notifier).clearTokens();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final base = ref.watch(backendBaseUrlProvider);
  return ApiClient(
    baseUrl: base,
    getAccessToken: ref.watch(getAccessTokenProvider),
    getRefreshToken: ref.watch(getRefreshTokenProvider),
    saveTokens: ref.watch(saveTokensProvider),
    clearTokens: ref.watch(clearTokensProvider),
    // 👇 Tell the client to prefix all requests with /api/v1
    apiPrefix: '/api/v1',
    refreshPath: '/api/v1/auth/refresh',
  );
});

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository(ref.watch(apiClientProvider));
});

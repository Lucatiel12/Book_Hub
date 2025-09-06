import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream of connectivity changes, normalized to a single ConnectivityResult.
/// Works with connectivity_plus that returns List<ConnectivityResult>.
final connectivityStreamProvider = StreamProvider<ConnectivityResult>((
  ref,
) async* {
  final connectivity = Connectivity();

  // Emit the initial status immediately
  final initialList =
      await connectivity.checkConnectivity(); // List<ConnectivityResult>
  yield initialList.isNotEmpty ? initialList.first : ConnectivityResult.none;

  // Then listen to updates
  yield* connectivity.onConnectivityChanged.map(
    (List<ConnectivityResult> results) =>
        results.isNotEmpty ? results.first : ConnectivityResult.none,
  );
});

/// Boolean: true when offline (no network).
final isOfflineProvider = Provider<bool>((ref) {
  final async = ref.watch(connectivityStreamProvider);
  return async.maybeWhen(
    data: (result) => result == ConnectivityResult.none,
    orElse: () => false, // assume online until we know
  );
});

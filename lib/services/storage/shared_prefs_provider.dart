import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPrefsProvider must be overridden in main()');
});

class SettingsKeys {
  static const wifiOnlyDownloads = 'settings_wifi_only_downloads';
  static const autoRetryDownloads = 'settings_auto_retry_downloads';
  static const maxConcurrentDownloads = 'settings_max_concurrent_downloads';
}

class SettingsState {
  final bool wifiOnlyDownloads;
  final bool autoRetryDownloads;
  final int maxConcurrentDownloads; // 1..5 (for example)

  const SettingsState({
    required this.wifiOnlyDownloads,
    required this.autoRetryDownloads,
    required this.maxConcurrentDownloads,
  });

  SettingsState copyWith({
    bool? wifiOnlyDownloads,
    bool? autoRetryDownloads,
    int? maxConcurrentDownloads,
  }) => SettingsState(
    wifiOnlyDownloads: wifiOnlyDownloads ?? this.wifiOnlyDownloads,
    autoRetryDownloads: autoRetryDownloads ?? this.autoRetryDownloads,
    maxConcurrentDownloads:
        maxConcurrentDownloads ?? this.maxConcurrentDownloads,
  );

  static const defaults = SettingsState(
    wifiOnlyDownloads: false,
    autoRetryDownloads: true,
    maxConcurrentDownloads: 2,
  );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this._prefs) : super(SettingsState.defaults) {
    _load();
  }
  final SharedPreferences _prefs;

  Future<void> _load() async {
    state = SettingsState(
      wifiOnlyDownloads:
          _prefs.getBool(SettingsKeys.wifiOnlyDownloads) ??
          SettingsState.defaults.wifiOnlyDownloads,
      autoRetryDownloads:
          _prefs.getBool(SettingsKeys.autoRetryDownloads) ??
          SettingsState.defaults.autoRetryDownloads,
      maxConcurrentDownloads:
          _prefs.getInt(SettingsKeys.maxConcurrentDownloads) ??
          SettingsState.defaults.maxConcurrentDownloads,
    );
  }

  Future<void> setWifiOnly(bool v) async {
    await _prefs.setBool(SettingsKeys.wifiOnlyDownloads, v);
    state = state.copyWith(wifiOnlyDownloads: v);
  }

  Future<void> setAutoRetry(bool v) async {
    await _prefs.setBool(SettingsKeys.autoRetryDownloads, v);
    state = state.copyWith(autoRetryDownloads: v);
  }

  Future<void> setMaxConcurrent(int v) async {
    final clamped = v.clamp(1, 5);
    await _prefs.setInt(SettingsKeys.maxConcurrentDownloads, clamped);
    state = state.copyWith(maxConcurrentDownloads: clamped);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    final prefs = ref.watch(sharedPrefsProvider);
    return SettingsNotifier(prefs);
  },
);

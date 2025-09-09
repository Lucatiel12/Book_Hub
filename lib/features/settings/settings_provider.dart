// lib/features/settings/settings_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:book_hub/services/storage/shared_prefs_provider.dart';

const _kWifiOnlyKey = 'settings_wifi_only';
const _kAutoRetryKey = 'settings_auto_retry';
const _kAutoRestoreKey = 'settings_auto_restore';
const _kMaxConcurrentKey = 'settings_max_concurrent';

class DownloadSettings {
  final bool wifiOnly;
  final bool autoRetry;
  final bool autoRestoreOnLaunch;
  final int maxConcurrent; // NEW

  const DownloadSettings({
    required this.wifiOnly,
    required this.autoRetry,
    required this.autoRestoreOnLaunch,
    this.maxConcurrent = 2, // default 2
  });
  DownloadSettings copyWith({
    bool? wifiOnly,
    bool? autoRetry,
    bool? autoRestoreOnLaunch,
    int? maxConcurrent, // NEW
  }) {
    return DownloadSettings(
      wifiOnly: wifiOnly ?? this.wifiOnly,
      autoRetry: autoRetry ?? this.autoRetry,
      autoRestoreOnLaunch: autoRestoreOnLaunch ?? this.autoRestoreOnLaunch,
      maxConcurrent: maxConcurrent ?? this.maxConcurrent,
    );
  }
}

class DownloadSettingsController extends StateNotifier<DownloadSettings> {
  final SharedPreferences _prefs;

  DownloadSettingsController(this._prefs)
    : super(
        const DownloadSettings(
          wifiOnly: false,
          autoRetry: true,
          autoRestoreOnLaunch: true,
          maxConcurrent: 2, // default
        ),
      ) {
    _load();
  }

  void _load() {
    state = DownloadSettings(
      wifiOnly: _prefs.getBool(_kWifiOnlyKey) ?? false,
      autoRetry: _prefs.getBool(_kAutoRetryKey) ?? true,
      autoRestoreOnLaunch: _prefs.getBool(_kAutoRestoreKey) ?? true,
      maxConcurrent: _prefs.getInt(_kMaxConcurrentKey) ?? 2, // NEW
    );
  }

  Future<void> setWifiOnly(bool value) async {
    await _prefs.setBool(_kWifiOnlyKey, value);
    state = state.copyWith(wifiOnly: value);
  }

  Future<void> setAutoRetry(bool value) async {
    await _prefs.setBool(_kAutoRetryKey, value);
    state = state.copyWith(autoRetry: value);
  }

  Future<void> setAutoRestoreOnLaunch(bool value) async {
    await _prefs.setBool(_kAutoRestoreKey, value);
    state = state.copyWith(autoRestoreOnLaunch: value);
  }

  Future<void> setMaxConcurrent(int value) async {
    // NEW
    final v = value.clamp(1, 5);
    await _prefs.setInt(_kMaxConcurrentKey, v);
    state = state.copyWith(maxConcurrent: v);
  }
}

final downloadSettingsProvider =
    StateNotifierProvider<DownloadSettingsController, DownloadSettings>((ref) {
      final sp = ref.watch(sharedPrefsProvider);
      return DownloadSettingsController(sp);
    });

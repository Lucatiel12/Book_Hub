// lib/features/settings/locale_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:book_hub/services/storage/shared_prefs_provider.dart';

enum AppLanguage { system, en, ar }

extension AppLanguageX on AppLanguage {
  Locale? get locale => switch (this) {
    AppLanguage.system => null, // This means use the device's locale
    AppLanguage.en => const Locale('en'),
    AppLanguage.ar => const Locale('ar'),
  };

  String get key => switch (this) {
    AppLanguage.system => 'system',
    AppLanguage.en => 'en',
    AppLanguage.ar => 'ar',
  };

  static AppLanguage fromKey(String? v) {
    return switch (v) {
      'en' => AppLanguage.en,
      'ar' => AppLanguage.ar,
      _ => AppLanguage.system,
    };
  }
}

class LocaleNotifier extends StateNotifier<AppLanguage> {
  static const _k = 'app_language';
  final SharedPreferences _sp;

  LocaleNotifier(this._sp) : super(AppLanguageX.fromKey(_sp.getString(_k)));

  void set(AppLanguage lang) {
    state = lang;
    if (lang == AppLanguage.system) {
      _sp.remove(_k);
    } else {
      _sp.setString(_k, lang.key);
    }
  }
}

final appLanguageProvider = StateNotifierProvider<LocaleNotifier, AppLanguage>((
  ref,
) {
  final sp = ref.watch(sharedPrefsProvider);
  return LocaleNotifier(sp);
});

// <<< ADD THIS NEW PROVIDER AT THE END OF THE FILE
/// Provides the current [Locale] based on the user's selection
/// in [appLanguageProvider].
final localeProvider = Provider<Locale?>((ref) {
  final lang = ref.watch(appLanguageProvider);
  return lang.locale;
});

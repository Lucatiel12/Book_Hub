import 'package:shared_preferences/shared_preferences.dart';

enum ReaderThemeMode { light, dark, sepia, custom }

class ReaderPrefs {
  static SharedPreferences? _sp;
  static Future<void> _ensure() async {
    _sp ??= await SharedPreferences.getInstance();
  }

  // THEME MODE
  static Future<ReaderThemeMode> getThemeMode() async {
    await _ensure();
    final v = _sp!.getString('reader.themeMode') ?? 'light';
    switch (v) {
      case 'dark':
        return ReaderThemeMode.dark;
      case 'sepia':
        return ReaderThemeMode.sepia;
      case 'custom':
        return ReaderThemeMode.custom;
      default:
        return ReaderThemeMode.light;
    }
  }

  static Future<void> setThemeMode(ReaderThemeMode m) async {
    await _ensure();
    final s = switch (m) {
      ReaderThemeMode.dark => 'dark',
      ReaderThemeMode.sepia => 'sepia',
      ReaderThemeMode.custom => 'custom',
      _ => 'light',
    };
    await _sp!.setString('reader.themeMode', s);
  }

  // CUSTOM COLORS (ARGB ints)
  static Future<int?> getCustomBg() async {
    await _ensure();
    return _sp!.getInt('reader.custom.bg');
  }

  static Future<int?> getCustomText() async {
    await _ensure();
    return _sp!.getInt('reader.custom.text');
  }

  static Future<void> setCustomColors({
    required int bg,
    required int text,
  }) async {
    await _ensure();
    await _sp!.setInt('reader.custom.bg', bg);
    await _sp!.setInt('reader.custom.text', text);
  }

  // FONT SIZE
  static Future<double> getFontSize() async {
    await _ensure();
    return _sp!.getDouble('reader.fontSize') ?? 16.0;
  }

  static Future<void> setFontSize(double v) async {
    await _ensure();
    await _sp!.setDouble('reader.fontSize', v);
  }
}

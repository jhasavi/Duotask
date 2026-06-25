import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _dailySummaryKey = 'daily_summary_enabled';
  static const String _languageKey = 'language_code';
  static const String _defaultVisibilityKey = 'default_task_visibility';

  SharedPreferences? _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  bool _dailySummaryEnabled = true;
  String _languageCode = 'en';
  String _defaultTaskVisibility = 'personal';

  ThemeMode get themeMode => _themeMode;
  bool get dailySummaryEnabled => _dailySummaryEnabled;
  String get languageCode => _languageCode;
  String get defaultTaskVisibility => _defaultTaskVisibility;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    if (_prefs == null) return;

    // Load theme mode
    final themeModeIndex = _prefs!.getInt(_themeModeKey);
    if (themeModeIndex != null) {
      _themeMode = ThemeMode.values[themeModeIndex];
    }

    // Load daily summary preference
    _dailySummaryEnabled = _prefs!.getBool(_dailySummaryKey) ?? true;

    // Load language
    _languageCode = _prefs!.getString(_languageKey) ?? 'en';

    _defaultTaskVisibility =
        _prefs!.getString(_defaultVisibilityKey) ?? 'personal';

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setInt(_themeModeKey, mode.index);
    notifyListeners();
  }

  Future<void> setDailySummaryEnabled(bool enabled) async {
    _dailySummaryEnabled = enabled;
    await _prefs?.setBool(_dailySummaryKey, enabled);
    notifyListeners();
  }

  Future<void> setLanguageCode(String code) async {
    _languageCode = code;
    await _prefs?.setString(_languageKey, code);
    notifyListeners();
  }

  Future<void> setDefaultTaskVisibility(String visibility) async {
    _defaultTaskVisibility = visibility;
    await _prefs?.setString(_defaultVisibilityKey, visibility);
    notifyListeners();
  }

  String getThemeModeDisplayName() {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  String getLanguageDisplayName() {
    switch (_languageCode) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      default:
        return 'English';
    }
  }
}

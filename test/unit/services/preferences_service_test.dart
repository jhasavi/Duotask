import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:duotask/services/preferences_service.dart';

void main() {
  late PreferencesService preferencesService;

  setUp(() async {
    // Initialize shared preferences with mock values
    SharedPreferences.setMockInitialValues({});
    preferencesService = PreferencesService();
    await preferencesService.initialize();
  });

  group('PreferencesService - Theme Mode', () {
    test('default theme mode is system', () {
      expect(preferencesService.themeMode, ThemeMode.system);
    });

    test('setThemeMode updates theme mode', () async {
      await preferencesService.setThemeMode(ThemeMode.dark);
      expect(preferencesService.themeMode, ThemeMode.dark);
    });

    test('setThemeMode persists across service restarts', () async {
      await preferencesService.setThemeMode(ThemeMode.light);
      
      // Create new instance
      final newService = PreferencesService();
      await newService.initialize();
      
      expect(newService.themeMode, ThemeMode.light);
    });

    test('getThemeModeDisplayName returns correct name', () async {
      await preferencesService.setThemeMode(ThemeMode.light);
      expect(preferencesService.getThemeModeDisplayName(), 'Light');
      
      await preferencesService.setThemeMode(ThemeMode.dark);
      expect(preferencesService.getThemeModeDisplayName(), 'Dark');
      
      await preferencesService.setThemeMode(ThemeMode.system);
      expect(preferencesService.getThemeModeDisplayName(), 'System');
    });
  });

  group('PreferencesService - Daily Summary', () {
    test('daily summary is enabled by default', () {
      expect(preferencesService.dailySummaryEnabled, true);
    });

    test('setDailySummaryEnabled updates setting', () async {
      await preferencesService.setDailySummaryEnabled(false);
      expect(preferencesService.dailySummaryEnabled, false);
    });

    test('setDailySummaryEnabled persists across service restarts', () async {
      await preferencesService.setDailySummaryEnabled(false);
      
      // Create new instance
      final newService = PreferencesService();
      await newService.initialize();
      
      expect(newService.dailySummaryEnabled, false);
    });
  });

  group('PreferencesService - Language', () {
    test('default language is English', () {
      expect(preferencesService.languageCode, 'en');
    });

    test('setLanguageCode updates language', () async {
      await preferencesService.setLanguageCode('es');
      expect(preferencesService.languageCode, 'es');
    });

    test('setLanguageCode persists across service restarts', () async {
      await preferencesService.setLanguageCode('fr');
      
      // Create new instance
      final newService = PreferencesService();
      await newService.initialize();
      
      expect(newService.languageCode, 'fr');
    });

    test('getLanguageDisplayName returns correct names', () async {
      await preferencesService.setLanguageCode('en');
      expect(preferencesService.getLanguageDisplayName(), 'English');
      
      await preferencesService.setLanguageCode('es');
      expect(preferencesService.getLanguageDisplayName(), 'Español');
      
      await preferencesService.setLanguageCode('fr');
      expect(preferencesService.getLanguageDisplayName(), 'Français');
    });

    test('supports English language', () async {
      await preferencesService.setLanguageCode('en');
      expect(preferencesService.getLanguageDisplayName(), 'English');
    });

    test('supports Spanish language', () async {
      await preferencesService.setLanguageCode('es');
      expect(preferencesService.getLanguageDisplayName(), 'Español');
    });

    test('supports French language', () async {
      await preferencesService.setLanguageCode('fr');
      expect(preferencesService.getLanguageDisplayName(), 'Français');
    });
  });

  group('PreferencesService - Multiple Settings', () {
    test('can update multiple settings independently', () async {
      await preferencesService.setThemeMode(ThemeMode.dark);
      await preferencesService.setLanguageCode('es');
      await preferencesService.setDailySummaryEnabled(false);

      expect(preferencesService.themeMode, ThemeMode.dark);
      expect(preferencesService.languageCode, 'es');
      expect(preferencesService.dailySummaryEnabled, false);
    });

    test('all settings persist together', () async {
      await preferencesService.setThemeMode(ThemeMode.light);
      await preferencesService.setLanguageCode('fr');
      await preferencesService.setDailySummaryEnabled(true);

      // Create new instance
      final newService = PreferencesService();
      await newService.initialize();

      expect(newService.themeMode, ThemeMode.light);
      expect(newService.languageCode, 'fr');
      expect(newService.dailySummaryEnabled, true);
    });
  });

  group('PreferencesService - Notifications', () {
    test('notifies listeners on theme mode change', () async {
      var notified = false;
      preferencesService.addListener(() {
        notified = true;
      });

      await preferencesService.setThemeMode(ThemeMode.dark);
      expect(notified, true);
    });

    test('notifies listeners on language change', () async {
      var notified = false;
      preferencesService.addListener(() {
        notified = true;
      });

      await preferencesService.setLanguageCode('es');
      expect(notified, true);
    });

    test('notifies listeners on daily summary change', () async {
      var notified = false;
      preferencesService.addListener(() {
        notified = true;
      });

      await preferencesService.setDailySummaryEnabled(false);
      expect(notified, true);
    });
  });
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailPreferencesService extends ChangeNotifier {
  final SupabaseClient _supabase;

  bool _dailyEmailEnabled = true;
  String _timezone = 'UTC';
  bool _isLoading = false;
  String? _errorMessage;

  EmailPreferencesService(this._supabase);

  bool get dailyEmailEnabled => _dailyEmailEnabled;
  String get timezone => _timezone;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// A fixed-offset IANA zone (e.g. "Etc/GMT-5") derived from the device's
  /// current UTC offset. Used as the default when a user has never set a
  /// timezone explicitly. Falls back to UTC for non-whole-hour offsets
  /// (e.g. UTC+5:30), since Etc/GMT zones only cover whole hours.
  static String deviceOffsetTimezone() {
    final offset = DateTime.now().timeZoneOffset;
    if (offset.inMinutes % 60 != 0) return 'UTC';
    final hours = offset.inHours;
    if (hours == 0) return 'UTC';
    // Etc/GMT sign convention is inverted relative to the usual UTC+N.
    final sign = hours > 0 ? '-' : '+';
    return 'Etc/GMT$sign${hours.abs()}';
  }

  Future<void> loadPreferences(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('email_preferences')
          .select('daily_email_enabled, timezone')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        _dailyEmailEnabled = response['daily_email_enabled'] as bool? ?? true;
        _timezone = response['timezone'] as String? ?? 'UTC';
      } else {
        final defaultTimezone = deviceOffsetTimezone();
        await _supabase.from('email_preferences').insert({
          'user_id': userId,
          'daily_email_enabled': true,
          'timezone': defaultTimezone,
        });
        _dailyEmailEnabled = true;
        _timezone = defaultTimezone;
      }
    } on PostgrestException catch (e) {
      if (kDebugMode) print('Email preferences load error: ${e.message}');
      _dailyEmailEnabled = true;
    } on SocketException {
      _errorMessage = 'No internet connection';
    } catch (e) {
      if (kDebugMode) print('Email preferences load error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> setDailyEmailEnabled(String userId, bool enabled) async {
    _errorMessage = null;

    try {
      await _supabase.from('email_preferences').upsert({
        'user_id': userId,
        'daily_email_enabled': enabled,
        'updated_at': DateTime.now().toIso8601String(),
      });

      _dailyEmailEnabled = enabled;
      notifyListeners();
      return true;
    } on PostgrestException catch (e) {
      _errorMessage = 'Failed to update email preferences: ${e.message}';
      notifyListeners();
      return false;
    } on SocketException {
      _errorMessage = 'No internet connection';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to update email preferences';
      notifyListeners();
      return false;
    }
  }

  Future<bool> setTimezone(String userId, String timezone) async {
    _errorMessage = null;

    try {
      await _supabase.from('email_preferences').upsert({
        'user_id': userId,
        'timezone': timezone,
        'updated_at': DateTime.now().toIso8601String(),
      });

      _timezone = timezone;
      notifyListeners();
      return true;
    } on PostgrestException catch (e) {
      _errorMessage = 'Failed to update timezone: ${e.message}';
      notifyListeners();
      return false;
    } on SocketException {
      _errorMessage = 'No internet connection';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to update timezone';
      notifyListeners();
      return false;
    }
  }
}

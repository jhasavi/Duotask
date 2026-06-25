import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailPreferencesService extends ChangeNotifier {
  final SupabaseClient _supabase;

  bool _dailyEmailEnabled = true;
  bool _isLoading = false;
  String? _errorMessage;

  EmailPreferencesService(this._supabase);

  bool get dailyEmailEnabled => _dailyEmailEnabled;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadPreferences(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('email_preferences')
          .select('daily_email_enabled')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        _dailyEmailEnabled = response['daily_email_enabled'] as bool? ?? true;
      } else {
        await _supabase.from('email_preferences').insert({
          'user_id': userId,
          'daily_email_enabled': true,
        });
        _dailyEmailEnabled = true;
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
}

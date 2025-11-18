import 'package:flutter/services.dart';

/// Haptic feedback helper for consistent haptic responses across the app
class HapticHelper {
  HapticHelper._();

  /// Light impact haptic - for button taps and selections
  static Future<void> lightImpact() async {
    await HapticFeedback.lightImpact();
  }

  /// Medium impact haptic - for task state changes (claim, unclaim)
  static Future<void> mediumImpact() async {
    await HapticFeedback.mediumImpact();
  }

  /// Heavy impact haptic - for important actions (task completion, deletion)
  static Future<void> heavyImpact() async {
    await HapticFeedback.heavyImpact();
  }

  /// Selection haptic - for slider movements and selections
  static Future<void> selectionClick() async {
    await HapticFeedback.selectionClick();
  }

  /// Vibrate - for errors or important notifications
  static Future<void> vibrate() async {
    await HapticFeedback.vibrate();
  }

  /// Success haptic - combination for successful operations (task completion)
  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }

  /// Error haptic - for error states
  static Future<void> error() async {
    await HapticFeedback.vibrate();
  }

  /// Delete haptic - for destructive actions
  static Future<void> delete() async {
    await HapticFeedback.heavyImpact();
  }
}

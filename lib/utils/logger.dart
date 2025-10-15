import 'package:flutter/foundation.dart';

/// Simple logger wrapper. Replace with a full-featured logger later if needed.
class Log {
  static void debug(String message) {
    debugPrint('[DEBUG] $message');
  }

  static void info(String message) {
    debugPrint('[INFO] $message');
  }

  static void warn(String message) {
    debugPrint('[WARN] $message');
  }

  static void error(String message, [Object? err, StackTrace? st]) {
    debugPrint('[ERROR] $message');
    if (err != null) debugPrint('  err: $err');
    if (st != null) debugPrint('  stack: $st');
  }
}

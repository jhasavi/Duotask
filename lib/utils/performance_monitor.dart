import 'dart:async';
import 'dart:developer' as developer;
import '../utils/logger.dart';

/// Performance monitoring utility for tracking app performance
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Map<String, Stopwatch> _timers = {};
  final Map<String, List<Duration>> _measurements = {};

  /// Start timing an operation
  void startTimer(String operation) {
    _timers[operation] = Stopwatch()..start();
    Log.debug('Started timing: $operation');
  }

  /// Stop timing an operation and log the result
  void stopTimer(String operation) {
    final timer = _timers[operation];
    if (timer != null) {
      timer.stop();
      final duration = timer.elapsed;

      // Store measurement for analytics
      _measurements.putIfAbsent(operation, () => []).add(duration);

      // Log performance data
      Log.info('Performance: $operation took ${duration.inMilliseconds}ms');

      // Log to developer console for debugging
      developer.log(
        'Performance: $operation took ${duration.inMilliseconds}ms',
        name: 'PerformanceMonitor',
        level: 800, // Info level
      );

      _timers.remove(operation);
    }
  }

  /// Measure the execution time of an async operation
  Future<T> measureAsync<T>(
    String operation,
    Future<T> Function() callback,
  ) async {
    startTimer(operation);
    try {
      final result = await callback();
      stopTimer(operation);
      return result;
    } catch (e) {
      stopTimer(operation);
      rethrow;
    }
  }

  /// Measure the execution time of a synchronous operation
  T measureSync<T>(
    String operation,
    T Function() callback,
  ) {
    startTimer(operation);
    try {
      final result = callback();
      stopTimer(operation);
      return result;
    } catch (e) {
      stopTimer(operation);
      rethrow;
    }
  }

  /// Get performance statistics for an operation
  Map<String, dynamic> getStats(String operation) {
    final measurements = _measurements[operation];
    if (measurements == null || measurements.isEmpty) {
      return {};
    }

    final sorted = List<Duration>.from(measurements)..sort();
    final total = measurements.fold<Duration>(
      Duration.zero,
      (sum, duration) => sum + duration,
    );

    return {
      'count': measurements.length,
      'total_ms': total.inMilliseconds,
      'average_ms': (total.inMilliseconds / measurements.length).round(),
      'min_ms': sorted.first.inMilliseconds,
      'max_ms': sorted.last.inMilliseconds,
      'median_ms': sorted[sorted.length ~/ 2].inMilliseconds,
    };
  }

  /// Get all performance statistics
  Map<String, Map<String, dynamic>> getAllStats() {
    final stats = <String, Map<String, dynamic>>{};
    for (final operation in _measurements.keys) {
      stats[operation] = getStats(operation);
    }
    return stats;
  }

  /// Clear all performance data
  void clearStats() {
    _measurements.clear();
    _timers.clear();
    Log.info('Performance stats cleared');
  }

  /// Log all performance statistics
  void logAllStats() {
    final stats = getAllStats();
    if (stats.isEmpty) {
      Log.info('No performance data available');
      return;
    }

    Log.info('=== Performance Statistics ===');
    for (final entry in stats.entries) {
      final operation = entry.key;
      final data = entry.value;
      Log.info('$operation: ${data['count']} calls, '
          'avg: ${data['average_ms']}ms, '
          'min: ${data['min_ms']}ms, '
          'max: ${data['max_ms']}ms');
    }
  }

  /// Check if an operation is taking too long
  bool isSlow(String operation, {int thresholdMs = 1000}) {
    final stats = getStats(operation);
    final average = stats['average_ms'] as int? ?? 0;
    return average > thresholdMs;
  }

  /// Get slow operations
  List<String> getSlowOperations({int thresholdMs = 1000}) {
    return _measurements.keys
        .where((operation) => isSlow(operation, thresholdMs: thresholdMs))
        .toList();
  }
}

/// Extension for easy performance monitoring
extension PerformanceMonitorExtension on Object {
  /// Measure async operation with automatic naming
  Future<T> measureAsync<T>(Future<T> Function() callback) {
    return PerformanceMonitor().measureAsync(
      runtimeType.toString(),
      callback,
    );
  }

  /// Measure sync operation with automatic naming
  T measureSync<T>(T Function() callback) {
    return PerformanceMonitor().measureSync(
      runtimeType.toString(),
      callback,
    );
  }
}

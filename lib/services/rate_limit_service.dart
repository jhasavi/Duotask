import 'dart:async';
import 'package:task_bubble/utils/logger.dart';

class RateLimitService {
  final Map<String, Map<String, List<DateTime>>> _attempts = {};
  final Duration _timeWindow;
  final int _maxAttempts;

  RateLimitService({
    Duration timeWindow = const Duration(minutes: 1),
    int maxAttempts = 5,
  })  : _timeWindow = timeWindow,
        _maxAttempts = maxAttempts;

  bool isRateLimited(String endpoint, String identifier) {
    _cleanupOldAttempts(endpoint, identifier);
    
    final attempts = _attempts[endpoint]?[identifier] ?? [];
    if (attempts.length >= _maxAttempts) {
      logger.warning('Rate limit exceeded for $endpoint ($identifier)');
      return true;
    }
    
    _attempts.putIfAbsent(endpoint, () => {});
    _attempts[endpoint]!.putIfAbsent(identifier, () => []).add(DateTime.now());
    
    return false;
  }

  void _cleanupOldAttempts(String endpoint, String identifier) {
    final now = DateTime.now();
    final endpointAttempts = _attempts[endpoint];
    if (endpointAttempts == null) return;
    
    final attempts = endpointAttempts[identifier];
    if (attempts == null) return;
    
    _attempts[endpoint]![identifier] = attempts
        .where((timestamp) => now.difference(timestamp) <= _timeWindow)
        .toList();
  }

  void resetAttempts(String endpoint, String identifier) {
    _attempts[endpoint]?[identifier]?.clear();
  }
}

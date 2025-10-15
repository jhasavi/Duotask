import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// Service for tracking analytics and user behavior
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  late SharedPreferences _prefs;
  final List<AnalyticsEvent> _pendingEvents = [];
  bool _isEnabled = AppConstants.enableAnalytics;

  /// Initialize the analytics service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadPendingEvents();
    Log.info('Analytics service initialized');
  }

  /// Track a custom event
  Future<void> trackEvent(
    String eventName, {
    Map<String, dynamic>? parameters,
    String? userId,
  }) async {
    if (!_isEnabled) return;

    final event = AnalyticsEvent(
      name: eventName,
      parameters: parameters ?? {},
      userId: userId,
      timestamp: DateTime.now(),
    );

    _pendingEvents.add(event);
    await _savePendingEvents();
    
    Log.debug('Tracked event: $eventName');
  }

  /// Track screen view
  Future<void> trackScreenView(
    String screenName, {
    String? userId,
  }) async {
    await trackEvent(
      'screen_view',
      parameters: {'screen_name': screenName},
      userId: userId,
    );
  }

  /// Track user action
  Future<void> trackUserAction(
    String action, {
    Map<String, dynamic>? parameters,
    String? userId,
  }) async {
    await trackEvent(
      'user_action',
      parameters: {
        'action': action,
        ...?parameters,
      },
      userId: userId,
    );
  }

  /// Track task creation
  Future<void> trackTaskCreated({
    String? taskId,
    String? taskTitle,
    bool isUrgent = false,
    String? userId,
  }) async {
    await trackEvent(
      'task_created',
      parameters: {
        'task_id': taskId,
        'task_title': taskTitle,
        'is_urgent': isUrgent,
      },
      userId: userId,
    );
  }

  /// Track task completion
  Future<void> trackTaskCompleted({
    String? taskId,
    String? taskTitle,
    Duration? completionTime,
    String? userId,
  }) async {
    await trackEvent(
      'task_completed',
      parameters: {
        'task_id': taskId,
        'task_title': taskTitle,
        'completion_time_seconds': completionTime?.inSeconds,
      },
      userId: userId,
    );
  }

  /// Track pairing events
  Future<void> trackPairing({
    required String eventType,
    String? pairId,
    String? userId,
  }) async {
    await trackEvent(
      'pairing_$eventType',
      parameters: {
        'pair_id': pairId,
      },
      userId: userId,
    );
  }

  /// Track handoff events
  Future<void> trackHandoff({
    required String eventType,
    String? taskId,
    String? fromUser,
    String? toUser,
    String? userId,
  }) async {
    await trackEvent(
      'handoff_$eventType',
      parameters: {
        'task_id': taskId,
        'from_user': fromUser,
        'to_user': toUser,
      },
      userId: userId,
    );
  }

  /// Track error events
  Future<void> trackError(
    String errorType, {
    String? errorMessage,
    String? stackTrace,
    String? userId,
  }) async {
    await trackEvent(
      'error',
      parameters: {
        'error_type': errorType,
        'error_message': errorMessage,
        'stack_trace': stackTrace,
      },
      userId: userId,
    );
  }

  /// Track performance metrics
  Future<void> trackPerformance(
    String metricName, {
    double? value,
    String? unit,
    Map<String, dynamic>? additionalData,
    String? userId,
  }) async {
    await trackEvent(
      'performance',
      parameters: {
        'metric_name': metricName,
        'value': value,
        'unit': unit,
        ...?additionalData,
      },
      userId: userId,
    );
  }

  /// Track app lifecycle events
  Future<void> trackAppLifecycle(String event) async {
    await trackEvent(
      'app_lifecycle',
      parameters: {'event': event},
    );
  }

  /// Get analytics summary
  Map<String, dynamic> getAnalyticsSummary() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final todayEvents = _pendingEvents.where(
      (event) => event.timestamp.isAfter(today),
    ).toList();

    final eventCounts = <String, int>{};
    for (final event in todayEvents) {
      eventCounts[event.name] = (eventCounts[event.name] ?? 0) + 1;
    }

    return {
      'total_events': _pendingEvents.length,
      'today_events': todayEvents.length,
      'event_counts': eventCounts,
      'last_event': _pendingEvents.isNotEmpty 
          ? _pendingEvents.last.timestamp.toIso8601String()
          : null,
    };
  }

  /// Send pending events to analytics server
  Future<void> sendPendingEvents() async {
    if (_pendingEvents.isEmpty) return;

    try {
      // In a real implementation, you would send these to your analytics service
      // For now, we'll just log them and clear them
      Log.info('Sending ${_pendingEvents.length} analytics events');
      
      for (final event in _pendingEvents) {
        Log.debug('Event: ${event.name} - ${event.parameters}');
      }

      _pendingEvents.clear();
      await _savePendingEvents();
      
      Log.info('Analytics events sent successfully');
    } catch (e) {
      Log.error('Failed to send analytics events: $e');
    }
  }

  /// Enable or disable analytics
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    Log.info('Analytics ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Check if analytics is enabled
  bool get isEnabled => _isEnabled;

  /// Clear all analytics data
  Future<void> clearData() async {
    _pendingEvents.clear();
    await _savePendingEvents();
    Log.info('Analytics data cleared');
  }

  /// Save pending events to local storage
  Future<void> _savePendingEvents() async {
    try {
      final eventsJson = _pendingEvents.map((e) => e.toJson()).toList();
      await _prefs.setString('analytics_events', jsonEncode(eventsJson));
    } catch (e) {
      Log.error('Failed to save analytics events: $e');
    }
  }

  /// Load pending events from local storage
  Future<void> _loadPendingEvents() async {
    try {
      final eventsJson = _prefs.getString('analytics_events');
      if (eventsJson != null) {
        final eventsList = jsonDecode(eventsJson) as List;
        _pendingEvents.clear();
        _pendingEvents.addAll(
          eventsList.map((e) => AnalyticsEvent.fromJson(e as Map<String, dynamic>)),
        );
      }
    } catch (e) {
      Log.error('Failed to load analytics events: $e');
    }
  }
}

/// Analytics event model
class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> parameters;
  final String? userId;
  final DateTime timestamp;

  AnalyticsEvent({
    required this.name,
    required this.parameters,
    this.userId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'parameters': parameters,
      'user_id': userId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return AnalyticsEvent(
      name: json['name'] as String,
      parameters: Map<String, dynamic>.from(json['parameters'] as Map),
      userId: json['user_id'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  String toString() {
    return 'AnalyticsEvent(name: $name, parameters: $parameters, timestamp: $timestamp)';
  }
}

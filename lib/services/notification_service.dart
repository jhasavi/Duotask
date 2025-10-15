import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import 'analytics_service.dart';

/// Service for managing notifications and user alerts
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  late SharedPreferences _prefs;
  final AnalyticsService _analytics = AnalyticsService();
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Initialize the notification service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    Log.info('Notification service initialized');
  }

  /// Get the messenger key for global snackbars
  GlobalKey<ScaffoldMessengerState> get messengerKey => _messengerKey;

  /// Show a success notification
  void showSuccess(
    String message, {
    Duration duration = AppConstants.notificationDelay,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    _showSnackBar(
      message: message,
      backgroundColor: Colors.green,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );

    _analytics.trackUserAction(
      'notification_shown',
      parameters: {'type': 'success', 'message': message},
    );
  }

  /// Show an error notification
  void showError(
    String message, {
    Duration duration = AppConstants.notificationDelay,
    VoidCallback? onRetry,
  }) {
    _showSnackBar(
      message: message,
      backgroundColor: Colors.red,
      duration: duration,
      onAction: onRetry,
      actionLabel: onRetry != null ? 'Retry' : null,
    );

    _analytics.trackUserAction(
      'notification_shown',
      parameters: {'type': 'error', 'message': message},
    );
  }

  /// Show a warning notification
  void showWarning(
    String message, {
    Duration duration = AppConstants.notificationDelay,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    _showSnackBar(
      message: message,
      backgroundColor: Colors.orange,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );

    _analytics.trackUserAction(
      'notification_shown',
      parameters: {'type': 'warning', 'message': message},
    );
  }

  /// Show an info notification
  void showInfo(
    String message, {
    Duration duration = AppConstants.notificationDelay,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    _showSnackBar(
      message: message,
      backgroundColor: Colors.blue,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );

    _analytics.trackUserAction(
      'notification_shown',
      parameters: {'type': 'info', 'message': message},
    );
  }

  /// Show a task-related notification
  void showTaskNotification({
    required String taskTitle,
    required String action,
    String? additionalInfo,
    VoidCallback? onTap,
  }) {
    final message = '$action: $taskTitle${additionalInfo != null ? ' - $additionalInfo' : ''}';
    
    _showSnackBar(
      message: message,
      backgroundColor: Colors.indigo,
      duration: const Duration(seconds: 4),
      onAction: onTap,
      actionLabel: 'View',
    );

    _analytics.trackUserAction(
      'task_notification_shown',
      parameters: {
        'task_title': taskTitle,
        'action': action,
        'additional_info': additionalInfo,
      },
    );
  }

  /// Show a handoff notification
  void showHandoffNotification({
    required String taskTitle,
    required String fromUser,
    required String toUser,
    VoidCallback? onReview,
  }) {
    final message = 'Handoff request: $taskTitle from $fromUser to $toUser';
    
    _showSnackBar(
      message: message,
      backgroundColor: Colors.purple,
      duration: const Duration(seconds: 6),
      onAction: onReview,
      actionLabel: 'Review',
    );

    _analytics.trackUserAction(
      'handoff_notification_shown',
      parameters: {
        'task_title': taskTitle,
        'from_user': fromUser,
        'to_user': toUser,
      },
    );
  }

  /// Show a pairing notification
  void showPairingNotification({
    required String eventType,
    String? partnerName,
    VoidCallback? onAction,
  }) {
    String message;
    String actionLabel;
    
    switch (eventType) {
      case 'request_received':
        message = 'Pairing request received${partnerName != null ? ' from $partnerName' : ''}';
        actionLabel = 'Review';
        break;
      case 'request_accepted':
        message = 'Pairing request accepted${partnerName != null ? ' by $partnerName' : ''}';
        actionLabel = 'View';
        break;
      case 'partner_online':
        message = 'Your partner is online';
        actionLabel = 'Chat';
        break;
      default:
        message = 'Pairing event: $eventType';
        actionLabel = 'View';
    }
    
    _showSnackBar(
      message: message,
      backgroundColor: Colors.teal,
      duration: const Duration(seconds: 4),
      onAction: onAction,
      actionLabel: actionLabel,
    );

    _analytics.trackUserAction(
      'pairing_notification_shown',
      parameters: {
        'event_type': eventType,
        'partner_name': partnerName,
      },
    );
  }

  /// Show a progress notification
  void showProgress({
    required String message,
    required double progress,
    VoidCallback? onCancel,
  }) {
    _showSnackBar(
      message: message,
      backgroundColor: Colors.grey[700]!,
      duration: const Duration(seconds: 2),
      onAction: onCancel,
      actionLabel: onCancel != null ? 'Cancel' : null,
      progress: progress,
    );
  }

  /// Show a confirmation dialog
  Future<bool> showConfirmation({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: _messengerKey.currentContext!,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDestructive 
                ? TextButton.styleFrom(foregroundColor: Colors.red)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );

    _analytics.trackUserAction(
      'confirmation_dialog_shown',
      parameters: {
        'title': title,
        'confirmed': result ?? false,
        'is_destructive': isDestructive,
      },
    );

    return result ?? false;
  }

  /// Show a bottom sheet with options
  Future<String?> showOptionsSheet({
    required String title,
    required List<OptionItem> options,
  }) async {
    final result = await showModalBottomSheet<String>(
      context: _messengerKey.currentContext!,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(title),
              leading: const Icon(Icons.more_horiz),
            ),
            const Divider(height: 1),
            ...options.map((option) => ListTile(
              leading: Icon(option.icon),
              title: Text(option.title),
              subtitle: option.subtitle != null ? Text(option.subtitle!) : null,
              onTap: () => Navigator.of(context).pop(option.value),
            )),
          ],
        ),
      ),
    );

    _analytics.trackUserAction(
      'options_sheet_shown',
      parameters: {
        'title': title,
        'selected_option': result,
        'total_options': options.length,
      },
    );

    return result;
  }

  /// Show a toast message
  void showToast(
    String message, {
    Duration duration = const Duration(seconds: 2),
    ToastType type = ToastType.info,
  }) {
    final backgroundColor = _getToastColor(type);
    
    _showSnackBar(
      message: message,
      backgroundColor: backgroundColor,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
    );

    _analytics.trackUserAction(
      'toast_shown',
      parameters: {
        'message': message,
        'type': type.name,
      },
    );
  }

  /// Clear all notifications
  void clearAll() {
    _messengerKey.currentState?.hideCurrentSnackBar();
  }

  /// Check if notifications are enabled
  bool get isEnabled {
    return _prefs.getBool('notifications_enabled') ?? true;
  }

  /// Enable or disable notifications
  Future<void> setEnabled(bool enabled) async {
    await _prefs.setBool('notifications_enabled', enabled);
    Log.info('Notifications ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Get notification settings
  Map<String, bool> getNotificationSettings() {
    return {
      'task_reminders': _prefs.getBool('notify_task_reminders') ?? true,
      'handoff_requests': _prefs.getBool('notify_handoff_requests') ?? true,
      'pairing_events': _prefs.getBool('notify_pairing_events') ?? true,
      'partner_online': _prefs.getBool('notify_partner_online') ?? false,
      'daily_summary': _prefs.getBool('notify_daily_summary') ?? true,
    };
  }

  /// Update notification settings
  Future<void> updateNotificationSettings(Map<String, bool> settings) async {
    for (final entry in settings.entries) {
      await _prefs.setBool('notify_${entry.key}', entry.value);
    }
    Log.info('Notification settings updated');
  }

  /// Private method to show snackbar
  void _showSnackBar({
    required String message,
    required Color backgroundColor,
    Duration? duration,
    VoidCallback? onAction,
    String? actionLabel,
    double? progress,
    SnackBarBehavior behavior = SnackBarBehavior.fixed,
    EdgeInsetsGeometry? margin,
  }) {
    final snackBar = SnackBar(
      content: progress != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            )
          : Text(message),
      backgroundColor: backgroundColor,
      duration: duration ?? AppConstants.notificationDelay,
      action: onAction != null && actionLabel != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: Colors.white,
              onPressed: onAction,
            )
          : null,
      behavior: behavior,
      margin: margin,
    );

    _messengerKey.currentState?.showSnackBar(snackBar);
  }

  /// Get toast color based on type
  Color _getToastColor(ToastType type) {
    switch (type) {
      case ToastType.success:
        return Colors.green;
      case ToastType.error:
        return Colors.red;
      case ToastType.warning:
        return Colors.orange;
      case ToastType.info:
      default:
        return Colors.blue;
    }
  }
}

/// Option item for bottom sheets
class OptionItem {
  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;

  const OptionItem({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
  });
}

/// Toast types
enum ToastType {
  success,
  error,
  warning,
  info,
}

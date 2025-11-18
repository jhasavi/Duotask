import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/task.dart';

class NotificationService extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _notifications;
  bool _isInitialized = false;
  bool _permissionGranted = false;

  NotificationService(this._notifications);

  bool get isInitialized => _isInitialized;
  bool get permissionGranted => _permissionGranted;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone data
      tz.initializeTimeZones();

      // Android initialization settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      final iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        onDidReceiveLocalNotification: (id, title, body, payload) async {
          // Handle notification tap on iOS
          if (kDebugMode) {
            print('iOS notification received: $title');
          }
        },
      );

      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          // Handle notification tap
          if (kDebugMode) {
            print('Notification tapped: ${details.payload}');
          }
        },
      );

      _isInitialized = initialized ?? false;

      if (_isInitialized) {
        await _requestPermissions();
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing notifications: $e');
      }
    }
  }

  Future<void> _requestPermissions() async {
    try {
      // Request Android 13+ notification permissions
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
        _permissionGranted = await androidPlugin?.requestNotificationsPermission() ?? false;
      }

      // Request iOS permissions
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosPlugin = _notifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        
        _permissionGranted = await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ?? false;
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting permissions: $e');
      }
    }
  }

  Future<void> scheduleTaskReminder(Task task) async {
    if (!_isInitialized || !_permissionGranted) return;
    if (task.dueDate == null) return;

    try {
      // Schedule notification 1 hour before due date
      final reminderTime = task.dueDate!.subtract(const Duration(hours: 1));
      
      // Don't schedule if reminder time is in the past
      if (reminderTime.isBefore(DateTime.now())) return;

      const androidDetails = AndroidNotificationDetails(
        'task_reminders',
        'Task Reminders',
        channelDescription: 'Notifications for upcoming tasks',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        task.id.hashCode,
        'Task Reminder',
        '${task.title} is due in 1 hour',
        tz.TZDateTime.from(reminderTime, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling task reminder: $e');
      }
    }
  }

  Future<void> cancelTaskReminder(String taskId) async {
    if (!_isInitialized) return;

    try {
      await _notifications.cancel(taskId.hashCode);
    } catch (e) {
      if (kDebugMode) {
        print('Error cancelling task reminder: $e');
      }
    }
  }

  Future<void> showTaskCompletedNotification(Task task, String partnerName) async {
    if (!_isInitialized || !_permissionGranted) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'task_updates',
        'Task Updates',
        channelDescription: 'Notifications for task status updates',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        task.id.hashCode,
        'Task Completed! 🎉',
        '$partnerName completed: ${task.title}',
        details,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error showing completion notification: $e');
      }
    }
  }

  Future<void> showTaskClaimedNotification(Task task, String partnerName) async {
    if (!_isInitialized || !_permissionGranted) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'task_updates',
        'Task Updates',
        channelDescription: 'Notifications for task status updates',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        task.id.hashCode,
        'Task Claimed',
        '$partnerName claimed: ${task.title}',
        details,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error showing claimed notification: $e');
      }
    }
  }

  Future<void> showDailySummary(int taskCount, int completedCount) async {
    if (!_isInitialized || !_permissionGranted) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'daily_summary',
        'Daily Summary',
        channelDescription: 'Daily task summary notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        999999, // Fixed ID for daily summary
        'Daily Task Summary',
        'You completed $completedCount out of $taskCount tasks today!',
        details,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error showing daily summary: $e');
      }
    }
  }

  Future<void> scheduleDailySummary({int hour = 20, int minute = 0}) async {
    if (!_isInitialized || !_permissionGranted) return;

    try {
      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

      // If time has passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        'daily_summary',
        'Daily Summary',
        channelDescription: 'Daily task summary notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        999999, // Fixed ID for daily summary
        'Daily Task Summary',
        'Check your task progress for today!',
        tz.TZDateTime.from(scheduledDate, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling daily summary: $e');
      }
    }
  }

  Future<void> cancelAllNotifications() async {
    if (!_isInitialized) return;

    try {
      await _notifications.cancelAll();
    } catch (e) {
      if (kDebugMode) {
        print('Error cancelling all notifications: $e');
      }
    }
  }
}

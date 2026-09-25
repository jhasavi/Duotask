import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/task.dart';

class NotificationService extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _notifications;
  bool _isInitialized = false;
  bool _permissionGranted = false;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  NotificationService(this._notifications);

  bool get isInitialized => _isInitialized;
  bool get permissionGranted => _permissionGranted;

  /// Requests push permission, registers this device's FCM token against
  /// [userId], and shows a local notification for any push that arrives
  /// while the app is in the foreground (FCM does not display those itself).
  ///
  /// Safe to call even when Firebase was never initialized (no real project
  /// configured yet — see docs/PUSH_NOTIFICATIONS_SETUP.md): every step is
  /// wrapped so a missing/placeholder Firebase config just leaves push
  /// notifications inactive rather than breaking anything else.
  Future<void> registerForPushNotifications(
    SupabaseClient supabase,
    String userId,
  ) async {
    if (kIsWeb) return; // Mobile-only for now.
    if (Firebase.apps.isEmpty) return; // Firebase wasn't initialized.

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token != null) {
        await _saveDeviceToken(supabase, userId, token);
      }

      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen((newToken) {
        _saveDeviceToken(supabase, userId, newToken);
      });

      await _foregroundMessageSubscription?.cancel();
      _foregroundMessageSubscription =
          FirebaseMessaging.onMessage.listen(_showForegroundMessage);
    } catch (e) {
      if (kDebugMode) {
        print('Push notification registration skipped: $e');
      }
    }
  }

  Future<void> _saveDeviceToken(
    SupabaseClient supabase,
    String userId,
    String token,
  ) async {
    try {
      await supabase.from('device_tokens').upsert(
        {
          'user_id': userId,
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'token',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error saving device token: $e');
      }
    }
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null || !_isInitialized || !_permissionGranted) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'nudges',
      'Nudges',
      channelDescription: 'Notifications when your partner nudges you',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      message.hashCode,
      notification.title ?? 'DuoTask',
      notification.body ?? '',
      details,
    );
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone data
      tz.initializeTimeZones();

      // Android initialization settings
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

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
        final androidPlugin =
            _notifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        _permissionGranted =
            await androidPlugin?.requestNotificationsPermission() ?? false;
      }

      // Request iOS permissions
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

        _permissionGranted = await iosPlugin?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
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

  Future<void> showTaskCompletedNotification(
      Task task, String partnerName) async {
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

  Future<void> showTaskClaimedNotification(
      Task task, String partnerName) async {
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

  @override
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
    super.dispose();
  }
}

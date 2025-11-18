class AppConstants {
  // App Info
  static const String appName = 'DuoTask';
  static const String appTagline = 'Task sharing made fun';
  
  // Animation Durations
  static const Duration bubbleAnimationDuration = Duration(milliseconds: 300);
  static const Duration pageTransitionDuration = Duration(milliseconds: 250);
  static const Duration confettiDuration = Duration(seconds: 3);
  
  // Bubble Sizes
  static const double bubbleSizeUnclaimed = 120.0;
  static const double bubbleSizeClaimed = 90.0;
  static const double bubbleSizeCompleted = 70.0;
  static const double bubbleSizeUrgent = 140.0;
  
  // Task Limits
  static const int maxTaskTitleLength = 100;
  static const int maxTaskDescriptionLength = 500;
  
  // Pairing
  static const int pairingCodeLength = 8;
  
  // Notifications
  static const int taskReminderHours = 1;
  static const int dailySummaryHour = 20;
  static const int dailySummaryMinute = 0;
  
  // Realtime
  static const Duration realtimeRetryDelay = Duration(seconds: 5);
  
  // Date Formats
  static const String dateFormat = 'MMM d, y';
  static const String timeFormat = 'h:mm a';
  static const String dateTimeFormat = 'MMM d, y h:mm a';
  
  // Error Messages
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork = 'Network error. Please check your connection.';
  static const String errorAuth = 'Authentication failed. Please try again.';
  static const String errorInvalidPairingCode = 'Invalid pairing code.';
  
  // Success Messages
  static const String successTaskCreated = 'Task created successfully!';
  static const String successTaskCompleted = 'Task completed! 🎉';
  static const String successPaired = 'Successfully paired!';
  static const String successUnpaired = 'Pairing removed.';
}

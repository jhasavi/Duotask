/// App-wide constants and configuration values
class AppConstants {
  // App Information
  static const String appName = 'DuoTask';
  static const String appVersion = '1.0.0';
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // Spacing
  static const double smallPadding = 8.0;
  static const double defaultPadding = 16.0;
  static const double largePadding = 24.0;
  static const double extraLargePadding = 32.0;
  
  // Border Radius
  static const double borderRadius = 8.0;
  static const double largeBorderRadius = 12.0;
  static const double extraLargeBorderRadius = 16.0;
  
  // Colors
  static const int primaryColorValue = 0xFF2196F3;
  static const int secondaryColorValue = 0xFF03DAC6;
  static const int errorColorValue = 0xFFB00020;
  static const int successColorValue = 0xFF4CAF50;
  static const int warningColorValue = 0xFFFF9800;
  
  // Text Sizes
  static const double smallTextSize = 12.0;
  static const double defaultTextSize = 14.0;
  static const double largeTextSize = 16.0;
  static const double extraLargeTextSize = 18.0;
  static const double titleTextSize = 20.0;
  static const double headlineTextSize = 24.0;
  
  // Storage Keys
  static const String userPrefsKey = 'user_preferences';
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language';
  static const String onboardingKey = 'onboarding_completed';
  static const String lastSyncKey = 'last_sync_timestamp';
  
  // Task Status
  static const String taskStatusUnclaimed = 'unclaimed';
  static const String taskStatusClaimed = 'claimed';
  static const String taskStatusCompleted = 'completed';
  static const String taskStatusArchived = 'archived';
  
  // Handoff Status
  static const String handoffStatusProposed = 'proposed';
  static const String handoffStatusAccepted = 'accepted';
  static const String handoffStatusDeclined = 'declined';
  static const String handoffStatusExpired = 'expired';
  
  // Task Limits
  static const int maxTaskTitleLength = 100;
  static const int minTaskTitleLength = 1;
  static const int maxTasksPerUser = 1000;
  static const int maxTasksPerPair = 500;
  
  // Pair Code
  static const int maxPairCodeLength = 8;
  static const int minPairCodeLength = 4;
  
  // Cache Settings
  static const Duration cacheExpiration = Duration(minutes: 30);
  static const int maxCachedTasks = 100;
  static const int maxCachedUsers = 50;
  
  // Network Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);
  
  // File Upload Limits
  static const int maxFileSizeMB = 10;
  static const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
  static const List<String> allowedDocumentExtensions = ['pdf', 'doc', 'docx', 'txt'];
  
  // Notification Settings
  static const Duration notificationDelay = Duration(seconds: 2);
  static const int maxNotificationRetries = 3;
  
  // UI Constants
  static const double taskBubbleMinSize = 80.0;
  static const double taskBubbleMaxSize = 120.0;
  static const double taskBubbleSpacing = 12.0;
  
  // Validation
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int minEmailLength = 5;
  static const int maxEmailLength = 254;
  
  // Performance
  static const int maxConcurrentOperations = 5;
  static const Duration operationTimeout = Duration(seconds: 10);
  
  // Error Messages
  static const String genericErrorMessage = 'Something went wrong. Please try again.';
  static const String networkErrorMessage = 'Network error. Please check your connection.';
  static const String authErrorMessage = 'Authentication failed. Please log in again.';
  static const String validationErrorMessage = 'Please check your input and try again.';
  
  // Success Messages
  static const String taskCreatedMessage = 'Task created successfully!';
  static const String taskUpdatedMessage = 'Task updated successfully!';
  static const String taskDeletedMessage = 'Task deleted successfully!';
  static const String pairRequestSentMessage = 'Pair request sent successfully!';
  static const String pairRequestAcceptedMessage = 'Pair request accepted!';
  
  // Default Values
  static const String defaultUserName = 'Anonymous User';
  static const String defaultTaskTitle = 'New Task';
  static const String defaultPairCode = '0000';
  
  // API Endpoints (if needed)
  static const String apiBaseUrl = 'https://api.duotask.com';
  static const String apiVersion = 'v1';
  
  // Feature Flags
  static const bool enableOfflineMode = true;
  static const bool enablePushNotifications = true;
  static const bool enableAnalytics = false;
  static const bool enableCrashReporting = false;
}

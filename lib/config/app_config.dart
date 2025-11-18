import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Supabase
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Google OAuth
  static String get googleWebClientId => dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';
  static String get googleIosClientId => dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '';
  static String get googleAndroidClientId => dotenv.env['GOOGLE_ANDROID_CLIENT_ID'] ?? '';

  // App
  static String get appName => dotenv.env['APP_NAME'] ?? 'DuoTask';
  static String get appVersion => dotenv.env['APP_VERSION'] ?? '1.0.0';
  static bool get debugMode => dotenv.env['DEBUG_MODE'] == 'true';

  // Validation
  static bool get isConfigured {
    return supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  }
}

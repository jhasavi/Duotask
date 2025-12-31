import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Supabase
  static String get supabaseUrl =>
      const String.fromEnvironment('SUPABASE_URL',
          defaultValue: '') != ''
          ? const String.fromEnvironment('SUPABASE_URL')
          : (dotenv.env['SUPABASE_URL'] ?? '');
  
  static String get supabaseAnonKey =>
      const String.fromEnvironment('SUPABASE_ANON_KEY',
          defaultValue: '') != ''
          ? const String.fromEnvironment('SUPABASE_ANON_KEY')
          : (dotenv.env['SUPABASE_ANON_KEY'] ?? '');

  // Redirects
  static String get webRedirectUrl =>
      const String.fromEnvironment('WEB_REDIRECT_URL',
          defaultValue: '') != ''
          ? const String.fromEnvironment('WEB_REDIRECT_URL')
          : (dotenv.env['WEB_REDIRECT_URL'] ?? '');

  // Google OAuth
  static String get googleWebClientId =>
      const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID',
          defaultValue: '') != ''
          ? const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID')
          : (dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '');
  
  static String get googleIosClientId =>
      const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID',
          defaultValue: '') != ''
          ? const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID')
          : (dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '');
  
  static String get googleAndroidClientId =>
      const String.fromEnvironment('GOOGLE_ANDROID_CLIENT_ID',
          defaultValue: '') != ''
          ? const String.fromEnvironment('GOOGLE_ANDROID_CLIENT_ID')
          : (dotenv.env['GOOGLE_ANDROID_CLIENT_ID'] ?? '');

  // App
  static String get appName =>
      const String.fromEnvironment('APP_NAME',
          defaultValue: '') != ''
          ? const String.fromEnvironment('APP_NAME')
          : (dotenv.env['APP_NAME'] ?? 'DuoTask');
  
  static String get appVersion =>
      const String.fromEnvironment('APP_VERSION',
          defaultValue: '') != ''
          ? const String.fromEnvironment('APP_VERSION')
          : (dotenv.env['APP_VERSION'] ?? '1.0.0');
  
  static bool get debugMode =>
      const String.fromEnvironment('DEBUG_MODE') == 'true' ||
      dotenv.env['DEBUG_MODE'] == 'true';

  // Validation
  static bool get isConfigured {
    return supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  }
}

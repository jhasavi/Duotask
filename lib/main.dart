import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'config/app_config.dart';
import 'config/theme.dart';
import 'services/auth_service.dart';
import 'services/task_service.dart';
import 'services/pairing_service.dart';
import 'services/notification_service.dart';
import 'services/nudge_service.dart';
import 'services/preferences_service.dart';
import 'services/connectivity_service.dart';
import 'services/email_preferences_service.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

/// Loads a `.env` for local development only.
///
/// Release builds pass configuration via `--dart-define` (see
/// `scripts/build_web.sh`), which [AppConfig] prefers over dotenv. No `.env`
/// is bundled into a release build — one previously was, and shipped secrets
/// to anyone who requested `/assets/.env`. Every lookup here is best-effort so
/// that a build with no dotenv asset at all still starts.
Future<void> _loadEnvironment() async {
  for (final file in ['.env', '.env.example']) {
    try {
      await dotenv.load(fileName: file);
      return;
    } catch (_) {
      // Try the next candidate.
    }
  }
  // Nothing to load: rely entirely on --dart-define values.
  dotenv.testLoad(fileInput: '');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _loadEnvironment();

  if (!AppConfig.isConfigured) {
    // Fail fast and visibly rather than booting into an app whose every
    // request will 401 against a placeholder key.
    runApp(const _ConfigErrorApp());
    return;
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // Initialize local notifications
  final notifications = FlutterLocalNotificationsPlugin();

  // Initialize preferences
  final preferencesService = PreferencesService();
  await preferencesService.initialize();

  // Initialize connectivity
  final connectivityService = ConnectivityService();
  await connectivityService.initialize();

  runApp(DuoTaskApp(
    notifications: notifications,
    preferencesService: preferencesService,
    connectivityService: connectivityService,
  ),);
}

class DuoTaskApp extends StatelessWidget {
  final FlutterLocalNotificationsPlugin notifications;
  final PreferencesService preferencesService;
  final ConnectivityService connectivityService;

  const DuoTaskApp({
    super.key,
    required this.notifications,
    required this.preferencesService,
    required this.connectivityService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services
        Provider<SupabaseClient>(
          create: (_) => Supabase.instance.client,
        ),
        
        ChangeNotifierProvider<PreferencesService>.value(
          value: preferencesService,
        ),
        
        ChangeNotifierProvider<ConnectivityService>.value(
          value: connectivityService,
        ),
        
        ChangeNotifierProvider<AuthService>(
          create: (context) => AuthService(
            context.read<SupabaseClient>(),
          ),
        ),
        
        ChangeNotifierProvider<NotificationService>(
          create: (_) => NotificationService(notifications),
        ),
        
        ChangeNotifierProxyProvider<NotificationService, TaskService>(
          create: (context) => TaskService(
            context.read<SupabaseClient>(),
            context.read<NotificationService>(),
          ),
          update: (context, notificationService, previous) =>
              previous ?? TaskService(
                context.read<SupabaseClient>(),
                notificationService,
              ),
        ),
        
        ChangeNotifierProvider<PairingService>(
          create: (context) => PairingService(
            context.read<SupabaseClient>(),
          ),
        ),
        
        ChangeNotifierProvider<NudgeService>(
          create: (context) => NudgeService(
            context.read<SupabaseClient>(),
          ),
        ),

        ChangeNotifierProvider<EmailPreferencesService>(
          create: (context) => EmailPreferencesService(
            context.read<SupabaseClient>(),
          ),
        ),
      ],
      child: Consumer2<AuthService, PreferencesService>(
        builder: (context, authService, prefsService, _) {
          // Initialize notification service
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<NotificationService>().initialize();
          });

          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: prefsService.themeMode,
            home: authService.isAuthenticated
                ? const HomeScreen()
                : const AuthScreen(),
          );
        },
      ),
    );
  }
}

/// Shown when the app was built without valid Supabase configuration.
///
/// Without this, a misconfigured build renders a normal-looking sign-in screen
/// where every attempt fails with an opaque network error — which is how a
/// broken deploy previously reached users unnoticed.
class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48),
                SizedBox(height: 16),
                Text(
                  'DuoTask is not configured',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'This build has no valid Supabase URL or anon key. '
                  'Rebuild with scripts/build_web.sh, which supplies them '
                  'via --dart-define.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

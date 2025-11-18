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
import 'services/preferences_service.dart';
import 'services/connectivity_service.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

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
  ));
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

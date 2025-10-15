import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth_screen.dart';
import 'screens/modern_task_screen.dart';
import 'screens/welcome_onboarding_screen.dart';
import 'utils/logger.dart';
import 'services/app_dependencies.dart';
import 'utils/enhanced_theme.dart';
import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Set up a global error widget for uncaught errors
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Unexpected error:\n\n${details.exceptionAsString()}',
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  };
  // Firebase initialization removed for MVP cleanup
  try {
    await dotenv.load(fileName: '.env');
    Log.info('Dotenv loaded');
  } catch (e) {
    Log.warn('Dotenv not found, using default values for web');
  }
  
  try {
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    
    if (supabaseUrl == null || supabaseAnonKey == null) {
      Log.error('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env');
      Log.error('Please create a .env file with your Supabase credentials');
      Log.error('See env.example for the required format');
      
      runApp(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Configuration Error',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Missing Supabase configuration.\n\nPlease create a .env file with your Supabase credentials.\n\nSee env.example for the required format.',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Show instructions
                    },
                    child: const Text('View Setup Instructions'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
      return;
    }
    
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    Log.info('Supabase initialized successfully');
  } catch (e) {
    Log.error('Failed to initialize Supabase: $e');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Connection Error',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to connect to Supabase.\n\n$e',
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    return;
  }
  // Launch main app
  runApp(const DuoTaskApp());
}

class DuoTaskApp extends StatelessWidget {
  const DuoTaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppDependencies(
      child: MaterialApp(
        title: 'DuoTask',
        theme: EnhancedTheme.lightTheme,
        darkTheme: EnhancedTheme.darkTheme,
        themeMode: ThemeMode.system, // Automatically switch between light and dark
        home: const LaunchScreen(),
        // Add a fallback route for unknown navigation
        onUnknownRoute: (settings) => MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('Page not found: ${settings.name}'),
            ),
          ),
        ),
      ),
    );
  }
}



class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {
  bool _isLoading = true;
  bool _isPaired = false;
  String? _partnerName;
  bool _hasCompletedOnboarding = false;

  @override
  void initState() {
    super.initState();
    // Defer the auth check to after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboardingAndAuthStatus();
    });
  }

  Future<void> _checkOnboardingAndAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasCompletedOnboarding = prefs.getBool(AppConstants.onboardingKey) ?? false;
      
      if (!_hasCompletedOnboarding) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const WelcomeOnboardingScreen()),
        );
        return;
      }
      
      await _checkAuthStatus();
    } catch (e) {
      Log.error('Error checking onboarding status: $e');
      await _checkAuthStatus();
    }
  }

  Future<void> _checkAuthStatus() async {
    try {
      print('🔍 LaunchScreen: Checking auth status...');
      final user = Supabase.instance.client.auth.currentUser;
      print('🔍 LaunchScreen: Current user: ${user?.email} (${user?.id})');
      
      if (user == null) {
        print('🔍 LaunchScreen: No user found, navigating to AuthScreen');
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
        return;
      }

      print('🔍 LaunchScreen: User authenticated, checking pairing status...');

      // Check pairing status using new clean pairing service
      try {
        if (mounted) {
          final deps = AppDependencies.of(context);
          print('🔍 LaunchScreen: Getting current pair info for user: ${user.id}');
          final pairInfo = await deps.pairing.getCurrentPair();
          print('🔍 LaunchScreen: Current pair info result: $pairInfo');
          
          if (pairInfo != null && mounted) {
            setState(() {
              _isPaired = true;
              _partnerName = pairInfo['partner_name'];
            });
            print('🔍 LaunchScreen: Set paired status: $_isPaired, partner: $_partnerName');
          } else {
            print('🔍 LaunchScreen: No current pair found');
          }
        }
      } catch (e) {
        print('❌ LaunchScreen: Failed to get current pair info: $e');
        Log.warn('Failed to get current pair info: $e');
        // Continue without pairing info
      }

      print('🔍 LaunchScreen: Setting loading to false');
      setState(() => _isLoading = false);
      print('🔍 LaunchScreen: Auth check complete. Loading: $_isLoading, Paired: $_isPaired');
    } catch (e) {
      print('❌ LaunchScreen: Error checking auth status: $e');
      Log.error('Error checking auth status: $e');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.task_alt,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'DuoTask',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    return ModernTaskScreen(
      isPaired: _isPaired,
      partnerNameFromParent: _partnerName,
    );
  }
}


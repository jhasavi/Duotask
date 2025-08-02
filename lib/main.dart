import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/auth_screen.dart';
import 'screens/task_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    print('Warning: Could not load .env file: $e');
    print('Please create a .env file with your Supabase configuration');
  }
  
  // Note: Firebase is only for future push notifications
  // Authentication is handled entirely by Supabase
  print('ℹ️  Firebase initialization skipped - using Supabase for authentication');
  
  // Get Supabase configuration
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 
                     const String.fromEnvironment('SUPABASE_URL');
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? 
                         const String.fromEnvironment('SUPABASE_ANON_KEY');
  
  if (supabaseUrl == null || supabaseAnonKey == null) {
    print('Error: Missing Supabase configuration');
    print('Please set SUPABASE_URL and SUPABASE_ANON_KEY in your .env file or as environment variables');
    print('You can get these values from your Supabase project dashboard');
    return;
  }
  
  // Initialize Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  
  runApp(const DuoTaskApp());
}

class DuoTaskApp extends StatelessWidget {
  const DuoTaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DuoTask',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF667EEA),
          brightness: Brightness.light,
        ),
        fontFamily: 'SF Pro Display',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF64748B),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF64748B),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF667EEA), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  String? _oauthError;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      print('***** Auth state change: $event');
      
      if (event == AuthChangeEvent.signedOut) {
        print('User signed out, navigating to auth screen');
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthScreen()),
            (route) => false,
          );
        }
      } else if (event == AuthChangeEvent.signedIn) {
        print('User signed in: ${data.session?.user.email}');
        
        // Set loading to false immediately to prevent hanging
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        
        // Navigate to task screen immediately
        if (mounted) {
          print('Navigating to task screen...');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const TaskScreen()),
            (route) => false,
          );
        }
        
        // Handle OAuth user profile creation in background (non-blocking)
        if (data.session?.user != null) {
          print('Starting OAuth profile creation in background...');
          _authService.handleOAuthUserProfile(data.session!.user).catchError((e) {
            print('Error handling OAuth profile (non-blocking): $e');
          });
        }
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        print('Token refreshed for user: ${data.session?.user.email}');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    });
    
    // Check initial auth state
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      print('User already signed in: ${user.email}');
      setState(() {
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_oauthError != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                'OAuth Error',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(_oauthError!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _oauthError = null;
                  });
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      return const TaskScreen();
    } else {
      return const AuthScreen();
    }
  }
} 
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  runApp(const OAuthTestApp());
}

class OAuthTestApp extends StatelessWidget {
  const OAuthTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OAuth Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const OAuthTestPage(),
    );
  }
}

class OAuthTestPage extends StatefulWidget {
  const OAuthTestPage({super.key});

  @override
  State<OAuthTestPage> createState() => _OAuthTestPageState();
}

class _OAuthTestPageState extends State<OAuthTestPage> {
  String _status = 'Ready to test';
  String _error = '';

  Future<void> _testOAuth() async {
    setState(() {
      _status = 'Testing OAuth...';
      _error = '';
    });

    try {
      print('=== OAuth Test Start ===');
      print('Supabase URL: ${dotenv.env['SUPABASE_URL']}');
      print('Google Client ID: ${dotenv.env['GOOGLE_WEB_CLIENT_ID']}');
      
      const redirectUrl = 'http://localhost:5000';
      print('Using redirect URL: $redirectUrl');
      
      final response = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        queryParams: {
          'app_name': 'DuoTask',
        },
      );
      
      print('OAuth response: $response');
      
      setState(() {
        _status = 'OAuth initiated successfully!';
      });
      
    } catch (e) {
      print('OAuth error: $e');
      setState(() {
        _status = 'OAuth failed';
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OAuth Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: $_status',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Error: $_error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _testOAuth,
              child: const Text('Test Google OAuth'),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuration Check:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('• App redirect URL: http://localhost:5000'),
                    Text('• Supabase should have: http://localhost:5000'),
                    Text('• Google Console should have: http://localhost:5000'),
                    Text('• No trailing slashes'),
                    Text('• Exact protocol match (http vs https)'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 
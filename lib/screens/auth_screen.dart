import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../main.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _isLogin = true;
  bool _showCheckEmail = false;
  bool _switchedFromLogin = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // Check if a user exists with the given email
  Future<bool> _checkUserExists(String email) async {
    try {
      final client = Supabase.instance.client;
      final result = await client
          .from('usr')
          .select('id')
          .eq('email', email)
          .limit(1)
          .maybeSingle();
      return result != null;
    } catch (e) {
      print('Error checking user existence: $e');
      return false;
    }
  }

  Future<void> _submit() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _showCheckEmail = false;
    });
    try {
      if (_isLogin) {
        print('🔐 AuthScreen: Attempting login for: ${_emailController.text.trim()}');
        await _authService.signIn(
            _emailController.text.trim(), _passwordController.text.trim());
        print('🔐 AuthScreen: Login successful!');
        print('🔐 AuthScreen: Navigating back to main app...');
        // Force a rebuild of the main app
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => LaunchScreen()),
          );
        }
      } else {
        print('Attempting registration for: ${_emailController.text.trim()}');
        await _authService.signUp(
            _emailController.text.trim(), _passwordController.text.trim(),
            name: _nameController.text.trim());
        if (!mounted) return;
        setState(() {
          _showCheckEmail = true;
          _isLogin = true;
          _switchedFromLogin = false; // Reset flag after successful registration
        });
        return;
      }
    } catch (e) {
      final msg = e.toString();
      print('Auth error: $msg'); // Debug print
      
      if (_isLogin) {
        if (msg.contains('Invalid login credentials') ||
            msg.contains('No user found') ||
            msg.contains('Invalid email or password')) {
          if (!mounted) return;
          
          // Check if user exists to determine if it's wrong password vs new user
          final userExists = await _checkUserExists(_emailController.text.trim());
          
          if (!userExists) {
            // User doesn't exist - switch to registration
            setState(() {
              _isLogin = false; // Switch to registration tab
              // Keep the password for convenience - user can change it if needed
              _switchedFromLogin = true; // Flag to show helpful message
              _error = 'Account not found. Please register with this email to create your account.';
            });
          } else {
            // User exists but wrong password
            setState(() {
              _error = 'Incorrect password. Please check your password and try again.';
            });
          }
          return;
        } else if (msg.contains('Email not confirmed') ||
            msg.contains('Email not verified')) {
          if (!mounted) return;
          setState(() {
            _error = 'Please confirm your email before logging in.';
          });
          return;
        } else if (msg.contains('Too many requests')) {
          if (!mounted) return;
          setState(() {
            _error = 'Too many login attempts. Please try again later.';
          });
          return;
        }
      }
      
      if (!mounted) return;
      setState(() {
        _error = msg;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'DuoTask',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Collaborative tasks for two',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 36),
              ToggleButtons(
                isSelected: [_isLogin, !_isLogin],
                onPressed: (index) {
                  setState(() {
                    _isLogin = index == 0;
                    _switchedFromLogin = false; // Reset flag when manually switching
                    _error = null; // Clear any existing errors
                  });
                },
                borderRadius: BorderRadius.circular(8),
                selectedColor: Colors.white,
                color: Colors.grey[600],
                fillColor: Theme.of(context).colorScheme.primary,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Login',
                      style: TextStyle(
                        color: _isLogin ? Colors.white : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Register',
                      style: TextStyle(
                        color: !_isLogin ? Colors.white : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (!_isLogin && _switchedFromLogin) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'We\'ve pre-filled your email and password. Just add your name to create your account.',
                          style: TextStyle(color: Colors.blue[700], fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email),
                  filled: true,
                  fillColor: Colors.grey[50],
                  labelStyle: TextStyle(color: Colors.grey[700]),
                ),
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 18),
              if (!_isLogin) ...[
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.person),
                    filled: true,
                    fillColor: Colors.grey[50],
                    labelStyle: TextStyle(color: Colors.grey[700]),
                  ),
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 18),
              ],
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock),
                  filled: true,
                  fillColor: Colors.grey[50],
                  labelStyle: TextStyle(color: Colors.grey[700]),
                ),
                obscureText: true,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    textStyle: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isLogin ? 'Login' : 'Register'),
                ),
              ),
              if (_showCheckEmail) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Check your email to confirm your account, then login.',
                          style: TextStyle(color: Colors.blue[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Debug button for testing
              if (_isLogin) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    try {
                      print('Testing Supabase connection...');
                      final client = Supabase.instance.client;
                      print('Current user: ${client.auth.currentUser}');
                      
                      // Test a simple query
                      final result = await client.from('usr').select('count').limit(1);
                      print('Database connection test result: $result');
                      
                      setState(() {
                        _error = 'Connection test successful. Check console for details.';
                      });
                    } catch (e) {
                      print('Connection test failed: $e');
                      setState(() {
                        _error = 'Connection test failed: $e';
                      });
                    }
                  },
                  child: const Text('Test Connection (Debug)'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

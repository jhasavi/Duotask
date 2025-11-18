import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:math';
import 'dart:io';
import '../models/user.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase;
  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AuthService(this._supabase) {
    _initAuthListener();
  }

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  void _initAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) async {
      if (kDebugMode) {
        print('Auth state changed: ${data.event}');
        print('Session: ${data.session != null ? "exists" : "null"}');
      }
      final session = data.session;
      if (session != null) {
        await _loadCurrentUser();
      } else {
        _currentUser = null;
        notifyListeners();
      }
    });

    // Load user if already authenticated
    if (_supabase.auth.currentSession != null) {
      if (kDebugMode) {
        print('Current session exists, loading user...');
      }
      _loadCurrentUser();
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      if (kDebugMode) {
        print('Loading current user...');
      }
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        if (kDebugMode) {
          print('No auth user found');
        }
        return;
      }

      final userId = authUser.id;
      if (kDebugMode) {
        print('User ID: $userId');
      }

      // Try to get user profile
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        if (kDebugMode) {
          print('User profile found');
        }
        _currentUser = AppUser.fromJson(response);
        notifyListeners();
      } else {
        // Profile doesn't exist, create it
        if (kDebugMode) {
          print('User profile not found, creating...');
        }
        
        final displayName = authUser.userMetadata?['display_name'] as String? ??
            authUser.email?.split('@').first ??
            'User';

        // Generate pairing code
        final pairingCode = _generatePairingCode();

        await _supabase.from('users').insert({
          'id': userId,
          'email': authUser.email,
          'display_name': displayName,
          'pairing_code': pairingCode,
        });

        if (kDebugMode) {
          print('User profile created, loading...');
        }

        // Load the newly created user
        final newResponse = await _supabase
            .from('users')
            .select()
            .eq('id', userId)
            .single();

        _currentUser = AppUser.fromJson(newResponse);
        notifyListeners();
        if (kDebugMode) {
          print('User loaded successfully');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user: $e');
      }
      // If user can't be loaded/created, sign them out
      await _supabase.auth.signOut();
    }
  }

  String _generatePairingCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    var code = '';
    for (var i = 0; i < 8; i++) {
      code += chars[random.nextInt(chars.length)];
    }
    return code;
  }

  Future<bool> signInWithEmail(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session != null) {
        await _loadCurrentUser();
        _setLoading(false);
        return true;
      }

      _setError('Sign in failed. Please check your credentials.');
      _setLoading(false);
      return false;
    } on SocketException {
      _setError('No internet connection. Please check your network.');
      _setLoading(false);
      return false;
    } on AuthException catch (e) {
      _setError(_getAuthErrorMessage(e));
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred. Please try again.');
      if (kDebugMode) print('Sign in error: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    _setLoading(true);
    _clearError();

    try {
      if (kDebugMode) {
        print('Signing up with email: $email');
      }
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );

      if (kDebugMode) {
        print('Sign up response - Session: ${response.session != null}');
        print('Sign up response - User: ${response.user != null}');
      }

      if (response.session != null) {
        if (kDebugMode) {
          print('Session created, loading user...');
        }
        await _loadCurrentUser();
        _setLoading(false);
        return true;
      }

      if (kDebugMode) {
        print('No session created - email confirmation may be required');
      }
      _setError('Account created! Please check your email to verify your account.');
      _setLoading(false);
      return false;
    } on SocketException {
      _setError('No internet connection. Please check your network.');
      _setLoading(false);
      return false;
    } on AuthException catch (e) {
      if (kDebugMode) {
        print('AuthException during sign up: ${e.message}');
      }
      _setError(_getSignUpErrorMessage(e));
      _setLoading(false);
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error during sign up: $e');
      }
      _setError('An unexpected error occurred. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _clearError();

    try {
      // Web and mobile have different flows
      if (kIsWeb) {
        // Explicitly set redirect URL for web with PKCE flow
        final response = await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: kDebugMode 
            ? 'http://localhost:5000' 
            : 'https://www.namasteneedham.com',
        );
        _setLoading(false);
        return response;
      } else {
        // Mobile flow
        const webClientId = String.fromEnvironment(
          'GOOGLE_WEB_CLIENT_ID',
          defaultValue: '',
        );
        const iosClientId = String.fromEnvironment(
          'GOOGLE_IOS_CLIENT_ID',
          defaultValue: '',
        );

        final GoogleSignIn googleSignIn = GoogleSignIn(
          clientId: iosClientId,
          serverClientId: webClientId,
        );

        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          _setError('Google sign in was cancelled.');
          _setLoading(false);
          return false;
        }

        final googleAuth = await googleUser.authentication;
        final accessToken = googleAuth.accessToken;
        final idToken = googleAuth.idToken;

        if (accessToken == null) {
          _setError('Failed to get Google access token.');
          _setLoading(false);
          return false;
        }
        if (idToken == null) {
          _setError('Failed to get Google ID token.');
          _setLoading(false);
          return false;
        }

        final response = await _supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );

        if (response.session != null) {
          await _loadCurrentUser();
          _setLoading(false);
          return true;
        }

        _setError('Google sign in failed. Please try again.');
        _setLoading(false);
        return false;
      }
    } on SocketException {
      _setError('No internet connection. Please check your network.');
      _setLoading(false);
      return false;
    } on AuthException catch (e) {
      _setError(_getAuthErrorMessage(e));
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Google sign in failed. Please try again.');
      if (kDebugMode) print('Google sign in error: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signInWithMagicLink(String email) async {
    _setLoading(true);
    _clearError();

    try {
      // Let Supabase handle the OTP redirect automatically
      await _supabase.auth.signInWithOtp(
        email: email,
      );

      _setLoading(false);
      return true;
    } on SocketException {
      _setError('No internet connection. Please check your network.');
      _setLoading(false);
      return false;
    } on AuthException catch (e) {
      _setError(_getAuthErrorMessage(e));
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to send magic link. Please try again.');
      if (kDebugMode) print('Magic link error: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    _clearError();

    try {
      // Sign out from Google if needed
      if (!kIsWeb) {
        try {
          final GoogleSignIn googleSignIn = GoogleSignIn();
          await googleSignIn.signOut();
        } catch (e) {
          if (kDebugMode) {
            print('Google sign out error: $e');
          }
        }
      }

      await _supabase.auth.signOut();
      _currentUser = null;
      _setLoading(false);
    } on SocketException {
      _setError('No internet connection. Sign out may not be complete.');
      _setLoading(false);
    } catch (e) {
      _setError('Sign out failed. Please try again.');
      if (kDebugMode) print('Sign out error: $e');
      _setLoading(false);
    }
  }

  Future<bool> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final userId = _currentUser?.id;
      if (userId == null) {
        _setError('No user logged in. Please sign in first.');
        _setLoading(false);
        return false;
      }

      final updates = <String, dynamic>{};
      if (displayName != null) updates['display_name'] = displayName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      if (updates.isEmpty) {
        _setLoading(false);
        return true;
      }

      await _supabase.from('users').update(updates).eq('id', userId);

      await _loadCurrentUser();
      _setLoading(false);
      return true;
    } on SocketException {
      _setError('No internet connection. Please check your network.');
      _setLoading(false);
      return false;
    } on PostgrestException catch (e) {
      _setError('Failed to update profile: ${e.message}');
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to update profile. Please try again.');
      if (kDebugMode) print('Update profile error: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      // Let Supabase handle the password reset redirect automatically
      await _supabase.auth.resetPasswordForEmail(email);

      _setLoading(false);
      return true;
    } on SocketException {
      _setError('No internet connection. Please check your network.');
      _setLoading(false);
      return false;
    } on AuthException catch (e) {
      _setError(_getAuthErrorMessage(e));
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to send password reset email. Please try again.');
      if (kDebugMode) print('Reset password error: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    _setLoading(true);
    _clearError();

    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      _setLoading(false);
      return true;
    } on SocketException {
      _setError('No internet connection. Please check your network.');
      _setLoading(false);
      return false;
    } on AuthException catch (e) {
      _setError(_getAuthErrorMessage(e));
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to update password. Please try again.');
      if (kDebugMode) print('Update password error: $e');
      _setLoading(false);
      return false;
    }
  }

  String _getAuthErrorMessage(AuthException e) {
    switch (e.statusCode) {
      case '400':
        if (e.message.contains('Invalid login credentials')) {
          return 'Invalid email or password. Please try again.';
        }
        if (e.message.contains('Email not confirmed')) {
          return 'Please verify your email before signing in.';
        }
        return 'Invalid request. Please check your input.';
      case '422':
        return 'Invalid email format. Please check and try again.';
      case '429':
        return 'Too many attempts. Please wait a few minutes.';
      case '500':
        return 'Server error. Please try again later.';
      default:
        return e.message.isNotEmpty ? e.message : 'Authentication failed. Please try again.';
    }
  }

  String _getSignUpErrorMessage(AuthException e) {
    if (e.message.contains('User already registered')) {
      return 'This email is already registered. Please sign in instead.';
    }
    if (e.message.contains('Password should be at least')) {
      return 'Password must be at least 6 characters long.';
    }
    if (e.message.contains('invalid email')) {
      return 'Invalid email format. Please check and try again.';
    }
    return _getAuthErrorMessage(e);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:math';
import 'dart:io';
import '../config/app_config.dart';
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
    _supabase.auth.onAuthStateChange.listen((data) {
      if (kDebugMode) {
        print('🔐 [AuthListener] Auth state changed: ${data.event}');
        print('   Session exists: ${data.session != null}');
        if (data.session != null) {
          print('   User: ${data.session?.user.email}');
        }
      }
      
      final session = data.session;
      
      if (session != null) {
        if (kDebugMode) {
          print('🔐 [AuthListener] Session found → loading user...');
        }
        // Don't await here, let it happen in background and call notifyListeners when done
        _loadCurrentUser().then((_) {
          if (kDebugMode) {
            print('🔐 [AuthListener] User loaded: $_currentUser');
          }
        }).catchError((e) {
          if (kDebugMode) {
            print('🔐 [AuthListener] Error loading user: $e');
          }
        });
      } else {
        if (kDebugMode) {
          print('🔐 [AuthListener] No session → clearing user');
        }
        _currentUser = null;
        notifyListeners();
      }
    });

    // Load user if already authenticated on init
    if (_supabase.auth.currentSession != null) {
      if (kDebugMode) {
        print('🔐 [Init] Current session exists, loading user...');
      }
      _loadCurrentUser();
    }
  }

  Future<void> refreshUser() async {
    await _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      if (kDebugMode) {
        print('🔐 Loading current user...');
      }
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        if (kDebugMode) {
          print('🔐 No auth user found, clearing _currentUser');
        }
        _currentUser = null;
        notifyListeners();
        return;
      }

      final userId = authUser.id;
      if (kDebugMode) {
        print('🔐 Auth user ID: $userId (${authUser.email})');
      }

      // Try to get user profile
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        if (kDebugMode) {
          print('🔐 User profile found: ${response['email']}');
        }
        _currentUser = AppUser.fromJson(response);
        notifyListeners();
        if (kDebugMode) {
          print('🔐 ✅ User authenticated! isAuthenticated=$isAuthenticated');
        }
      } else {
        // Profile doesn't exist, create it
        if (kDebugMode) {
          print('🔐 User profile not found, creating...');
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
          print('🔐 User profile created with pairing code: $pairingCode');
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
          print('🔐 ✅ User created and authenticated! isAuthenticated=$isAuthenticated');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔐 ❌ Error loading user: $e');
      }
      // If user can't be loaded/created, clear state and sign out
      _currentUser = null;
      notifyListeners();
      try {
        await _supabase.auth.signOut();
      } catch (_) {}
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
      final trimmedEmail = email.trim().toLowerCase();
      final trimmedPassword = password.trim();
      
      if (kDebugMode) {
        print('🔐 Signing in with email: $trimmedEmail');
      }

      final response = await _supabase.auth.signInWithPassword(
        email: trimmedEmail,
        password: trimmedPassword,
      );

      if (kDebugMode) {
        print('🔐 Sign in response - Session: ${response.session != null}');
        print('🔐 Sign in response - User: ${response.user != null}');
      }

      if (response.session != null) {
        if (kDebugMode) {
          print('🔐 Session created, loading user...');
        }
        // Explicitly load the user and ensure it completes before returning
        await _loadCurrentUser();

        if (!isAuthenticated) {
          _setError('Sign in succeeded but your profile could not be loaded. Please try again.');
          _setLoading(false);
          return false;
        }
        
        // Give the UI a moment to rebuild
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (kDebugMode) {
          print('🔐 ✅ Sign in complete! isAuthenticated=$isAuthenticated, currentUser=${_currentUser?.email}');
        }
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
      // Trim and validate email
      final trimmedEmail = email.trim().toLowerCase();
      final trimmedPassword = password.trim();
      final trimmedDisplayName = displayName.trim();
      
      if (trimmedEmail.isEmpty) {
        _setError('Email is required');
        _setLoading(false);
        return false;
      }
      
      // Basic email validation
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(trimmedEmail)) {
        _setError('Invalid email format. Please enter a valid email address.');
        _setLoading(false);
        return false;
      }
      
      if (trimmedPassword.isEmpty || trimmedPassword.length < 6) {
        _setError('Password must be at least 6 characters long');
        _setLoading(false);
        return false;
      }
      
      if (trimmedDisplayName.isEmpty) {
        _setError('Display name is required');
        _setLoading(false);
        return false;
      }
      
      if (kDebugMode) {
        print('Signing up with email: $trimmedEmail');
      }
      
      final response = await _supabase.auth.signUp(
        email: trimmedEmail,
        password: trimmedPassword,
        data: {'display_name': trimmedDisplayName},
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

        if (!isAuthenticated) {
          _setError('Account created, but profile setup is still in progress. Please try signing in again.');
          _setLoading(false);
          return false;
        }

        _setLoading(false);
        return true;
      }

      // If no session was created, attempt immediate sign-in (email confirmation may be disabled)
      if (kDebugMode) {
        print('No session from sign up; attempting immediate sign in...');
      }
      try {
        final signInResponse = await _supabase.auth.signInWithPassword(
          email: trimmedEmail,
          password: trimmedPassword,
        );
        if (signInResponse.session != null) {
          await _loadCurrentUser();

          if (!isAuthenticated) {
            _setError('Account created, but profile setup is still in progress. Please try signing in again.');
            _setLoading(false);
            return false;
          }

          _setLoading(false);
          return true;
        }
      } on AuthException catch (e) {
        if (kDebugMode) {
          print('Immediate sign-in after signup failed: ${e.message}');
        }
        // Fall through to friendly message
      }

      _setError('Account created. You can sign in now or check your email if confirmation is enabled.');
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
        if (kDebugMode) print('Starting Google Sign-In for web...');
        final callbackUrl = AppConfig.webRedirectUrl.isNotEmpty
            ? AppConfig.webRedirectUrl
            : '${Uri.base.origin}/auth/callback.html';

        // For web, signInWithOAuth launches the OAuth flow
        // It returns true if the popup opened successfully
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: callbackUrl,
          authScreenLaunchMode: LaunchMode.platformDefault,
        );
        
        // For web, we don't wait for completion here
        // The callback will handle the session
        _setLoading(false);
        return true;
      } else {
        // Mobile flow
        final webClientId = AppConfig.googleWebClientId;
        final iosClientId = AppConfig.googleIosClientId;
        final androidClientId = AppConfig.googleAndroidClientId;

        if (webClientId.isEmpty) {
          _setError('Google Web Client ID is missing. Set GOOGLE_WEB_CLIENT_ID in .env');
          _setLoading(false);
          return false;
        }

        final GoogleSignIn googleSignIn = GoogleSignIn(
          clientId: Platform.isIOS
              ? (iosClientId.isNotEmpty ? iosClientId : null)
              : (androidClientId.isNotEmpty ? androidClientId : null),
          serverClientId: webClientId,
          scopes: const ['email', 'profile'],
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

          if (!isAuthenticated) {
            _setError('Google sign in succeeded but your profile could not be loaded. Please try again.');
            _setLoading(false);
            return false;
          }

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
      if (kDebugMode) print('Signing out...');
      
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
      
      if (kDebugMode) print('Sign out complete');
      
      _setLoading(false);
      
      // Ensure listeners are notified after loading is false
      notifyListeners();
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
        // Do not hard-block on email confirmation; provide a softer message
        if (e.message.contains('Email not confirmed')) {
          return 'Sign in requires email confirmation for this account. If you just confirmed, wait a minute and try again.';
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
    if (e.message.contains('Database error saving new user')) {
      return 'Could not create your account due to a database rule. Please confirm Supabase triggers and RLS are applied (users table + create_user_profile trigger).';
    }
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

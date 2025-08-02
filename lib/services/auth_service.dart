import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;
  final GoogleSignIn _googleSignIn = GoogleSignIn(); // Let iOS use Info.plist, Android use web client ID

  // Get current user
  User? get currentUser => _client.auth.currentUser;

  // Platform-specific Google OAuth Authentication
  Future<AuthResponse?> signInWithGoogle() async {
    try {
      print('Starting Google OAuth...');
      
      if (kIsWeb) {
        // Web: Use Supabase OAuth
        print('Using Supabase OAuth for web');
        const redirectUrl = 'http://localhost:5000';
        
        final response = await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirectUrl,
          queryParams: {
            'app_name': 'DuoTask',
            'app_logo': 'https://duotask.app/logo.png',
          },
        );
        
        print('Web OAuth response: $response');
        return null; // Let auth state listener handle it
      } else {
        // Mobile: Use native Google Sign-In
        print('Using native Google Sign-In for mobile');
        
        // Start the sign-in process
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        
        if (googleUser == null) {
          print('Google Sign-In was cancelled');
          return null;
        }
        
        print('Google Sign-In successful: ${googleUser.email}');
        
        // Get the auth details from the request
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        
        // Exchange Google token for Supabase session
        final response = await _client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: googleAuth.idToken!,
          accessToken: googleAuth.accessToken,
        );
        
        print('Mobile OAuth response: $response');
        return response;
      }
    } catch (e) {
      print('Google OAuth error: $e');
      
      // Provide more specific error messages
      String errorMessage = 'Google sign-in failed';
      if (e.toString().contains('redirect_uri_mismatch')) {
        errorMessage = 'OAuth redirect URL mismatch. Please check your Supabase OAuth settings.';
      } else if (e.toString().contains('invalid_client')) {
        errorMessage = 'OAuth client configuration error. Please check your Google OAuth settings.';
      } else if (e.toString().contains('access_denied')) {
        errorMessage = 'Access denied. Please try signing in again.';
      } else if (e.toString().contains('SIGN_IN_CANCELLED')) {
        errorMessage = 'Sign-in was cancelled.';
      } else {
        errorMessage = 'Google sign-in failed: ${e.toString()}';
      }
      
      throw Exception(errorMessage);
    }
  }

  // Email/Password Authentication
  Future<AuthResponse?> signInWithEmail(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      print('Email sign-in error: $e');
      throw Exception(_parseAuthError(e.toString()));
    }
  }

  // Email/Password Registration
  Future<AuthResponse?> signUpWithEmail(String email, String password, String name) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      
      if (response.user != null) {
        await _createUserProfile(response.user!, name, email);
      }
      
      return response;
    } catch (e) {
      print('Email sign-up error: $e');
      throw Exception(_parseAuthError(e.toString()));
    }
  }

  // Handle OAuth user profile creation
  Future<void> handleOAuthUserProfile(User authUser) async {
    try {
      print('Handling OAuth user profile for: ${authUser.email}');
      
      // Check if user profile already exists
      final existingProfile = await _client
          .from('usr')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();
      
      if (existingProfile == null) {
        print('Creating new OAuth user profile...');
        
        // Extract user information from OAuth data
        String name = 'User';
        if (authUser.userMetadata != null) {
          // Try to get name from user metadata
          name = authUser.userMetadata!['full_name'] ?? 
                 authUser.userMetadata!['name'] ?? 
                 authUser.userMetadata!['display_name'] ?? 
                 authUser.email?.split('@')[0] ?? 'User';
        }
        
        // Create new profile for OAuth user
        await _createUserProfile(
          authUser,
          name,
          authUser.email ?? '',
        );
        print('✅ OAuth user profile created successfully');
      } else {
        print('✅ OAuth user profile already exists');
      }
    } catch (e) {
      print('❌ Error handling OAuth user profile: $e');
      // Don't throw - auth user is still signed in
      // Just log the error and continue
    }
  }

  // User Profile Management
  Future<void> _createUserProfile(User authUser, String name, String email) async {
    try {
      print('Creating user profile for: $email');
      
      final userData = {
        'id': authUser.id,
        'name': name,
        'email': email,
        'pair_code': _generatePairCode(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      print('User data to insert: $userData');

      final result = await _client.from('usr').insert(userData).select();
      print('✅ User profile created successfully: $result');
    } catch (e) {
      print('❌ Failed to create user profile: $e');
      // Try to get more specific error information
      if (e.toString().contains('duplicate key')) {
        print('User profile already exists, this is expected for OAuth');
      } else {
        print('Database error details: $e');
      }
      // Don't throw - auth user is still created
    }
  }

  String _generatePairCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String code = '';
    for (int i = 0; i < 8; i++) {
      code += chars[(random + i) % chars.length];
    }
    return code;
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Google Sign-In (mobile)
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      
      // Sign out from Supabase
      await _client.auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
      throw Exception('Failed to sign out');
    }
  }

  // Unpair from partner
  Future<void> unpairFromPartner() async {
    try {
      final user = currentUser;
      if (user != null) {
        await _client
            .from('usr')
            .update({
              'paired_with': null,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', user.id);
        
        print('Unpaired from partner successfully');
      }
    } catch (e) {
      print('Unpair error: $e');
      throw Exception('Failed to unpair from partner');
    }
  }

  // Parse Auth Error
  String _parseAuthError(String error) {
    if (error.contains('Invalid login credentials')) {
      return 'Invalid email or password';
    } else if (error.contains('Email not confirmed')) {
      return 'Please check your email and confirm your account';
    } else if (error.contains('User already registered')) {
      return 'An account with this email already exists';
    } else if (error.contains('Password should be at least 6 characters')) {
      return 'Password must be at least 6 characters long';
    } else {
      return 'Authentication failed. Please try again.';
    }
  }
} 
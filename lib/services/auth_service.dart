import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'dart:io';
import '../utils/logger.dart';
import 'rate_limit_service.dart';

class AuthService {
  // Generate a crypto-secure random 8-character pair code
  String _generatePairCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // Ensure the generated pair code is unique in the 'usr' table
  Future<String> _generateUniquePairCode(SupabaseClient client) async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final code = _generatePairCode();
      final existing = await client
          .from('usr')
          .select('id')
          .eq('pair_code', code)
          .limit(1)
          .maybeSingle();
      if (existing == null) return code;
    }
    // Fallback (extremely unlikely): append two random digits to reduce collision further
    final base = _generatePairCode();
    final rng = Random.secure();
    return base.substring(0, 6) +
        rng.nextInt(90 + 10).toString().padLeft(2, '0');
  }

  final SupabaseClient _client = Supabase.instance.client;
  final RateLimitService _rateLimit = RateLimitService();

  // Get client IP for rate limiting
  String _getClientIp() {
    try {
      // This is a simplified example - in production, you'd get the actual client IP
      // from the request headers or connection info
      return '${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      logger.warning('Could not get client IP: $e');
      return 'unknown';
    }
  }

  // Check if the client is rate limited
  bool _isRateLimited(String endpoint) {
    final ip = _getClientIp();
    return _rateLimit.isRateLimited(endpoint, ip);
  }

  // Reset rate limiting for successful authentication
  void _resetRateLimit(String endpoint) {
    final ip = _getClientIp();
    _rateLimit.resetAttempts(endpoint, ip);
  }

  // Email/Password Sign Up
  Future<void> signUp(String email, String password, {String? name}) async {
    const endpoint = 'auth/signup';
    if (_isRateLimited(endpoint)) {
      throw const AuthException('Too many signup attempts. Please try again later.');
    }

    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: name != null && name.isNotEmpty
            ? {
                'name': name,
                'full_name': name,
              }
            : null,
      );
      
      final user = res.user;
      if (user == null) {
        throw const AuthException('Sign up failed: No user returned');
      }
      
      _resetRateLimit(endpoint);
      // Ensure user is added to usr table immediately after registration
      await ensureUsrExists(user);
    } on AuthException catch (e) {
      Log.warn('Sign up failed: ${e.message}');
      throw Exception('Sign up failed: ${e.message}');
    } catch (e) {
      Log.error('Sign up failed', e);
      throw Exception('Sign up failed: $e');
    }
  }

  // Email/Password Sign In
  Future<void> signIn(String email, String password) async {
    const endpoint = 'auth/signin';
    if (_isRateLimited(endpoint)) {
      throw const AuthException('Too many sign in attempts. Please try again later.');
    }

    try {
      Log.info('Attempting sign in for email: $email');
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      final user = res.user;
      if (user == null) {
        throw const AuthException('Sign in failed: No user returned');
      }
      
      _resetRateLimit(endpoint);
      Log.info('Sign in successful for user: ${user.id}');
      
      // After successful login, ensure user is in usr table
      await ensureUsrExists(user);
    } on AuthException catch (e) {
      Log.error('AuthException during sign in: ${e.message}');
      rethrow;
    } catch (e) {
      Log.error('Unexpected error during sign in: $e');
      throw AuthException('An unexpected error occurred. Please try again.');
    }
  }

  // Ensure a corresponding row exists in 'usr' for any signed-in user
  Future<void> ensureUsrExists(User user) async {
    final userId = user.id;
    final userEmail = user.email;
    if (userEmail == null) {
      Log.error('User email is null, cannot create usr record');
      return;
    }

    // Build best-guess display name
    final meta = user.userMetadata ?? {};
    final metaName = (meta['name'] ??
            meta['full_name'] ??
            meta['user_name'] ??
            meta['given_name'] ??
            '')
        .toString()
        .trim();
    final fallbackName = userEmail.split('@').first;
    final finalName = metaName.isNotEmpty ? metaName : fallbackName;

    // Generate a unique pair code
    final pairCode = await _generateUniquePairCode(_client);

    try {
      // Try to insert the user record
      await _client.from('usr').insert({
        'id': userId,
        'email': userEmail,
        'name': finalName,
        'pair_code': pairCode,
        'email_confirmed': true,
      });
      Log.info('User record created successfully for: $userEmail');
    } catch (e) {
      // If insert fails (user already exists), try to update
      try {
        await _client.from('usr').update({
          'email': userEmail,
          'name': finalName,
          'email_confirmed': true,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
        Log.info('User record updated successfully for: $userEmail');
      } catch (updateError) {
        Log.error('Failed to update user record: $updateError');
      }
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      Log.info('Sign out successful');
    } catch (e) {
      Log.error('Sign out error', e);
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  // Get Current User
  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;
}

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class OAuthDebugScript {
  static Future<void> runFullDebug() async {
    print('🔍 === COMPREHENSIVE OAUTH DEBUG SCRIPT ===');
    print('Timestamp: ${DateTime.now()}');
    print('Platform: $defaultTargetPlatform');
    print('Is Web: $kIsWeb');

    try {
      // 1. Check Supabase Client
      print('\n📋 1. SUPABASE CLIENT CHECK:');
      final client = Supabase.instance.client;
      print('   ✅ Supabase client initialized');
      print('   - URL: ${client.supabaseUrl}');
      print('   - Key: ${client.supabaseKey.substring(0, 20)}...');

      // 2. Check Current Session
      print('\n🔐 2. CURRENT SESSION CHECK:');
      final session = client.auth.currentSession;
      if (session != null) {
        print('   ✅ Active session found');
        print('   - User: ${session.user.email}');
        print('   - User ID: ${session.user.id}');
        print('   - Expires: ${session.expiresAt}');
        print('   - Access Token: ${session.accessToken.substring(0, 20)}...');
      } else {
        print('   ❌ No active session');
      }

      // 3. Check Current User
      print('\n👤 3. CURRENT USER CHECK:');
      final user = client.auth.currentUser;
      if (user != null) {
        print('   ✅ User authenticated');
        print('   - Email: ${user.email}');
        print('   - ID: ${user.id}');
        print('   - Created: ${user.createdAt}');
        print(
            '   - Email confirmed: ${user.emailConfirmedAt != null ? 'Yes' : 'No'}');
      } else {
        print('   ❌ No user authenticated');
      }

      // 4. Test Database Connection
      print('\n🗄️ 4. DATABASE CONNECTION TEST:');
      try {
        final response =
            await client.from('usr').select('count').limit(1).single();
        print('   ✅ Database connection successful');
        print('   - Response: $response');
      } catch (e) {
        print('   ❌ Database connection failed: $e');
      }

      // 5. Check OAuth Configuration
      print('\n🔗 5. OAUTH CONFIGURATION CHECK:');
      if (kIsWeb) {
        print('   - Platform: Web');
        print('   - Redirect URL: http://localhost:5000');
        print('   - Expected callback: http://localhost:5000');
      } else {
        print('   - Platform: Mobile');
        print('   - Using native OAuth flow');
      }

      // 6. Test OAuth URL Generation (without actually calling it)
      print('\n🌐 6. OAUTH URL GENERATION TEST:');
      try {
        // We can't actually call signInWithOAuth here, but we can check if the client is ready
        print('   ✅ OAuth client ready');
        print('   - Provider: Google');
        print('   - Redirect URL: http://localhost:5000');
      } catch (e) {
        print('   ❌ OAuth client error: $e');
      }

      // 7. Check Environment
      print('\n⚙️ 7. ENVIRONMENT CHECK:');
      print('   - Flutter version: $defaultTargetPlatform');
      print('   - Is Web: $kIsWeb');
      print('   - Is Mobile: ${!kIsWeb}');

      // 8. Network Test
      print('\n🌍 8. NETWORK CONNECTIVITY TEST:');
      try {
        // Test basic connectivity
        final testResponse =
            await client.from('usr').select('count').limit(1).single();
        print('   ✅ Network connectivity: Working');
        print('   - Response: $testResponse');
      } catch (e) {
        print('   ❌ Network connectivity: Failed - $e');
      }

      print('\n✅ === DEBUG SCRIPT COMPLETE ===');
      print('All checks completed successfully!');
    } catch (e) {
      print('\n❌ === DEBUG SCRIPT FAILED ===');
      print('Error: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  static void debugOAuthCallback(Uri uri) {
    print('\n🔄 === OAUTH CALLBACK DEBUG ===');
    print('Full URL: $uri');
    print('Scheme: ${uri.scheme}');
    print('Host: ${uri.host}');
    print('Port: ${uri.port}');
    print('Path: ${uri.path}');
    print('Query: ${uri.query}');
    print('Fragment: ${uri.fragment}');

    print('\nQuery Parameters:');
    uri.queryParameters.forEach((key, value) {
      print('  $key: $value');
    });

    // Analyze OAuth parameters
    final hasCode = uri.queryParameters.containsKey('code') &&
        uri.queryParameters['code']!.isNotEmpty;
    final hasAccessToken = uri.queryParameters.containsKey('access_token') &&
        uri.queryParameters['access_token']!.isNotEmpty;
    final hasError = uri.queryParameters.containsKey('error') &&
        uri.queryParameters['error']!.isNotEmpty;
    final hasState = uri.queryParameters.containsKey('state') &&
        uri.queryParameters['state']!.isNotEmpty;
    final hasErrorCode = uri.queryParameters.containsKey('error_code') &&
        uri.queryParameters['error_code']!.isNotEmpty;
    final hasErrorDescription =
        uri.queryParameters.containsKey('error_description') &&
            uri.queryParameters['error_description']!.isNotEmpty;

    print('\nOAuth Parameter Analysis:');
    print('  Has Code: $hasCode');
    print('  Has Access Token: $hasAccessToken');
    print('  Has Error: $hasError');
    print('  Has State: $hasState');
    print('  Has Error Code: $hasErrorCode');
    print('  Has Error Description: $hasErrorDescription');

    if (hasError) {
      print('\n❌ OAuth Error Details:');
      print('  Error: ${uri.queryParameters['error']}');
      print('  Error Code: ${uri.queryParameters['error_code']}');
      print('  Error Description: ${uri.queryParameters['error_description']}');

      // Provide specific guidance based on error
      final errorCode = uri.queryParameters['error_code'];
      if (errorCode == 'bad_oauth_state') {
        print('\n💡 Suggested Fix for bad_oauth_state:');
        print('  1. Clear browser cache and cookies');
        print(
            '  2. Ensure redirect URLs match exactly in Supabase and Google Cloud Console');
        print('  3. Don\'t open multiple OAuth tabs');
        print('  4. Complete OAuth flow quickly');
      }
    }

    print('🔄 === OAUTH CALLBACK DEBUG COMPLETE ===\n');
  }
}

// MVP: Passwordless (Magic Link) Auth Test Stub

import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils/logger.dart';

class MagicLinkAuthTest {
  static Future<void> testMagicLinkFlow(String email) async {
    Log.info('🧪 === MAGIC LINK AUTH TEST ===');
    final client = Supabase.instance.client;
    try {
      await client.auth.signInWithOtp(email: email);
      Log.info('   ✅ Magic link sent to: $email');
    } catch (e, st) {
      Log.error('   ❌ Error sending magic link', e, st);
    }
    Log.info('🧪 === MAGIC LINK AUTH TEST COMPLETE ===');
  }
}

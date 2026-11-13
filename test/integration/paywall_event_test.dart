// log_paywall_viewed RPC (migration 20261113000003_paywall_viewed_event.sql)
// against a real Supabase project: signed-in users can log a view, only for
// known sources, and anonymous callers are refused. The analytics schema
// isn't exposed over REST, so stored rows are checked by hand (see
// TESTING_GUIDE.md).
//
// Run with: flutter test --tags integration
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/integration_env.dart';

void main() {
  final env = IntegrationEnv.tryLoad();
  final skip = env == null ? IntegrationEnv.skipReason : null;

  const password = 'TestPassword123!';
  late SupabaseClient admin;
  final createdUserIds = <String>[];
  final userClients = <SupabaseClient>[];

  Future<(String, SupabaseClient)> signedInUser(String label) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final email = 'paywall-$label-$stamp@yopmail.com';
    final created = await admin.auth.admin.createUser(
      AdminUserAttributes(
        email: email,
        password: password,
        emailConfirm: true,
        userMetadata: {'display_name': 'Paywall Test $label'},
      ),
    );
    final id = created.user!.id;
    createdUserIds.add(id);
    await admin.from('users').upsert(
      {
        'id': id,
        'email': email,
        'display_name': 'Paywall Test $label',
        'pairing_code':
            'W${stamp.toString().substring(stamp.toString().length - 7)}',
      },
      onConflict: 'id',
    );
    final client = SupabaseClient(
      env!.url,
      env.anonKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    userClients.add(client);
    await client.auth.signInWithPassword(email: email, password: password);
    return (id, client);
  }

  setUpAll(() {
    if (env == null) return;
    admin = SupabaseClient(env.url, env.serviceRoleKey);
  });

  tearDownAll(() async {
    if (env == null) return;
    for (final c in userClients) {
      await c.dispose();
    }
    for (final id in createdUserIds) {
      try {
        await admin.auth.admin.deleteUser(id);
      } catch (_) {
        // Already deleted by the test itself.
      }
    }
  });

  test('a signed-in user can log a view, repeatedly, without error', skip: skip,
      () async {
    final (_, client) = await signedInUser('ok');
    await client.rpc('log_paywall_viewed',
        params: {'p_source': 'stats', 'p_can_upgrade': false});
    // A repeat within a minute is dropped server-side, not an error.
    await client.rpc('log_paywall_viewed', params: {'p_source': 'stats'});
  });

  test('rejects an unknown source', skip: skip, () async {
    final (_, client) = await signedInUser('bad');
    await expectLater(
      client.rpc('log_paywall_viewed', params: {'p_source': 'anything'}),
      throwsA(
        isA<PostgrestException>()
            .having((e) => e.message, 'message', contains('invalid_source')),
      ),
    );
  });

  test('refuses an unauthenticated caller', skip: skip, () async {
    final anon = SupabaseClient(env!.url, env.anonKey);
    addTearDown(anon.dispose);
    await expectLater(
      anon.rpc('log_paywall_viewed', params: {'p_source': 'stats'}),
      throwsA(isA<PostgrestException>()),
    );
  });
}

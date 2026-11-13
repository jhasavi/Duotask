// delete_my_account RPC (migration 20261113000001_delete_account_rpc.sql)
// against a real Supabase project: the account and its data are erased, the
// partner survives unpaired, and unauthenticated callers are refused.
//
// Creates and deletes real auth users; use a dedicated test project.
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
    final email = 'del-$label-$stamp@yopmail.com';
    final created = await admin.auth.admin.createUser(
      AdminUserAttributes(
        email: email,
        password: password,
        emailConfirm: true,
        userMetadata: {'display_name': 'Del Test $label'},
      ),
    );
    final id = created.user!.id;
    createdUserIds.add(id);
    await admin.from('users').upsert(
      {
        'id': id,
        'email': email,
        'display_name': 'Del Test $label',
        'pairing_code':
            'D${stamp.toString().substring(stamp.toString().length - 7)}',
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

  test('deletes the account and its tasks, and unpairs the partner', skip: skip,
      () async {
    final (aId, a) = await signedInUser('a');
    final (bId, _) = await signedInUser('b');

    await admin.from('users').update({'paired_with_id': bId}).eq('id', aId);
    await admin.from('users').update({'paired_with_id': aId}).eq('id', bId);
    final task = await admin
        .from('tasks')
        .insert({
          'title': 'Will be erased',
          'created_by_id': aId,
          'status': 'unclaimed',
        })
        .select('id')
        .single();

    await a.rpc('delete_my_account', params: {'p_password': password});

    expect(
      await admin.from('users').select('id').eq('id', aId),
      isEmpty,
      reason: 'profile row should be gone',
    );
    expect(
      await admin.from('tasks').select('id').eq('id', task['id'] as String),
      isEmpty,
      reason: 'tasks they created should be gone',
    );
    final partner =
        await admin.from('users').select().eq('id', bId).maybeSingle();
    expect(partner, isNotNull, reason: 'partner must survive');
    expect(partner!['paired_with_id'], isNull);
  });

  test('requires the password and rejects a wrong one', skip: skip, () async {
    final (id, client) = await signedInUser('pw');

    await expectLater(
      client.rpc('delete_my_account'),
      throwsA(
        isA<PostgrestException>()
            .having((e) => e.message, 'message', contains('password_required')),
      ),
    );
    // A wrong password is a return value, not an error, so the attempt
    // that the throttle counts isn't rolled back.
    expect(
      await client.rpc('delete_my_account', params: {'p_password': 'nope'}),
      'wrong_password',
    );
    expect(await admin.from('users').select('id').eq('id', id), isNotEmpty,
        reason: 'account must survive failed attempts');
  });

  test('locks out after five wrong passwords, even with the right one',
      skip: skip, () async {
    final (id, client) = await signedInUser('throttle');

    for (var i = 0; i < 5; i++) {
      expect(
        await client.rpc('delete_my_account', params: {'p_password': 'nope'}),
        'wrong_password',
      );
    }
    await expectLater(
      client.rpc('delete_my_account', params: {'p_password': password}),
      throwsA(
        isA<PostgrestException>()
            .having((e) => e.message, 'message', contains('too_many_attempts')),
      ),
    );
    expect(await admin.from('users').select('id').eq('id', id), isNotEmpty,
        reason: 'the lockout must hold even for the correct password');
  });

  test('refuses while a subscription is live', skip: skip, () async {
    final (id, client) = await signedInUser('sub');
    await admin.from('users').update({
      'is_premium': true,
      'premium_until': DateTime.now()
          .add(const Duration(days: 20))
          .toUtc()
          .toIso8601String(),
    }).eq('id', id);

    await expectLater(
      client.rpc('delete_my_account', params: {'p_password': password}),
      throwsA(
        isA<PostgrestException>().having(
            (e) => e.message, 'message', contains('active_subscription')),
      ),
    );
    expect(await admin.from('users').select('id').eq('id', id), isNotEmpty);
  });

  test('refuses an unauthenticated caller', skip: skip, () async {
    final anon = SupabaseClient(env!.url, env.anonKey);
    await expectLater(
      anon.rpc('delete_my_account'),
      throwsA(isA<PostgrestException>()),
    );
    await anon.dispose();
  });
}

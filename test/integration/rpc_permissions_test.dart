// Permission checks for the cycle_task_status RPC against a real Supabase
// project (migration 20261014000001_harden_rpc_permissions.sql).
//
// The RPC is SECURITY DEFINER, so it bypasses RLS; these tests make sure it
// enforces its own checks: the acting user is auth.uid() (not a client-supplied
// user_uuid), and only users allowed by the tasks UPDATE policy may act.
//
// Credentials come from the environment; see test/support/integration_env.dart.
// This creates and deletes real auth users, so point it at a dedicated test
// project, never production.
//
// Run with: flutter test --tags integration
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

  /// Creates a confirmed disposable user, signs it in with the anon key, and
  /// returns (userId, client acting as that user).
  Future<(String, SupabaseClient)> signedInUser(String label) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final email = 'rpc-$label-$stamp@yopmail.com';
    final created = await admin.auth.admin.createUser(
      AdminUserAttributes(
        email: email,
        password: password,
        emailConfirm: true,
        userMetadata: {'display_name': 'RPC Test $label'},
      ),
    );
    final id = created.user!.id;
    createdUserIds.add(id);

    await admin.from('users').upsert(
      {
        'id': id,
        'email': email,
        'display_name': 'RPC Test $label',
        'pairing_code':
            'R${stamp.toString().substring(stamp.toString().length - 7)}',
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

  Future<String> createPersonalTask(String ownerId) async {
    final row = await admin
        .from('tasks')
        .insert({
          'title': 'RPC permission probe',
          'created_by_id': ownerId,
          'status': 'unclaimed',
          'priority': 'normal',
          'recurrence': 'none',
          'visibility': 'personal',
          'is_personal': true,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  setUpAll(() {
    if (env != null) {
      admin = SupabaseClient(env.url, env.serviceRoleKey);
    }
  });

  tearDown(() async {
    if (env == null) return;
    for (final client in userClients) {
      await client.dispose();
    }
    userClients.clear();
    for (final id in createdUserIds) {
      await admin.from('tasks').delete().eq('created_by_id', id);
      await admin.from('users').delete().eq('id', id);
      try {
        await admin.auth.admin.deleteUser(id);
      } catch (_) {
        // Already gone; nothing to clean up.
      }
    }
    createdUserIds.clear();
  });

  test(
    'cycle_task_status lets the owner act but rejects outsiders and '
    'spoofed user_uuid',
    () async {
      final (ownerId, ownerClient) = await signedInUser('owner');
      final (outsiderId, outsiderClient) = await signedInUser('outsider');
      final taskId = await createPersonalTask(ownerId);

      // An unrelated user cannot cycle someone else's personal task, even
      // when claiming to be the owner.
      await expectLater(
        outsiderClient.rpc('cycle_task_status', params: {
          'task_uuid': taskId,
          'user_uuid': ownerId,
        }),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        outsiderClient.rpc('cycle_task_status', params: {
          'task_uuid': taskId,
          'user_uuid': outsiderId,
        }),
        throwsA(isA<PostgrestException>()),
      );

      // The owner cannot pass someone else's id either.
      await expectLater(
        ownerClient.rpc('cycle_task_status', params: {
          'task_uuid': taskId,
          'user_uuid': outsiderId,
        }),
        throwsA(isA<PostgrestException>()),
      );

      // The task is untouched by the rejected calls.
      final untouched =
          await admin.from('tasks').select().eq('id', taskId).single();
      expect(untouched['status'], 'unclaimed');

      // The legitimate call still works and records the real caller.
      final result = await ownerClient
          .rpc('cycle_task_status', params: {
            'task_uuid': taskId,
            'user_uuid': ownerId,
          })
          .select()
          .single();
      expect(result['status'], 'claimed');
      expect(result['claimed_by_id'], ownerId);
    },
    tags: ['integration'],
    skip: skip,
  );
}

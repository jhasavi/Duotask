// Row-level checks on pairings and nudges against a real Supabase project
// (migration 20261117000001_pairing_consent_and_nudge_guard.sql).
//
// Before that migration anyone could list every pending pairing code, a
// client could insert an 'active' pairing with any recipient, a requester
// could activate their own pending row, and anyone could nudge any user.
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
  final clients = <SupabaseClient>[];

  String uniqueCode() {
    final s = DateTime.now().microsecondsSinceEpoch.toString();
    return 'Q${s.substring(s.length - 7)}';
  }

  /// Creates a confirmed disposable user, signs it in with the anon key, and
  /// returns (userId, client acting as that user).
  Future<(String, SupabaseClient)> signedInUser(String label) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final email = 'pairperm-$label-$stamp@yopmail.com';
    final created = await admin.auth.admin.createUser(
      AdminUserAttributes(
        email: email,
        password: password,
        emailConfirm: true,
        userMetadata: {'display_name': 'Perm $label'},
      ),
    );
    final id = created.user!.id;
    createdUserIds.add(id);

    await admin.from('users').upsert(
      {
        'id': id,
        'email': email,
        'display_name': 'Perm $label',
        'pairing_code': uniqueCode(),
      },
      onConflict: 'id',
    );

    final client = SupabaseClient(
      env!.url,
      env.anonKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    clients.add(client);
    await client.auth.signInWithPassword(email: email, password: password);
    return (id, client);
  }

  setUpAll(() {
    if (env != null) {
      admin = SupabaseClient(env.url, env.serviceRoleKey);
    }
  });

  tearDown(() async {
    if (env == null) return;
    for (final client in clients) {
      await client.dispose();
    }
    clients.clear();
    for (final id in createdUserIds) {
      await admin
          .from('pairings')
          .delete()
          .or('requester_id.eq.$id,recipient_id.eq.$id');
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
    'pending codes are visible to their owner only',
    () async {
      final (ownerId, owner) = await signedInUser('owner');
      final (_, stranger) = await signedInUser('stranger');
      final code = uniqueCode();
      await owner.from('pairings').insert({
        'requester_id': ownerId,
        'pairing_code': code,
        'status': 'pending',
      });

      expect(await owner.from('pairings').select('id').eq('pairing_code', code),
          hasLength(1));
      expect(
          await stranger.from('pairings').select('id').eq('status', 'pending'),
          isEmpty);

      final anon = SupabaseClient(env!.url, env.anonKey);
      clients.add(anon);
      expect(await anon.from('pairings').select('id').eq('pairing_code', code),
          isEmpty);
    },
    tags: ['integration'],
    skip: skip,
  );

  test(
    'a client cannot create an active pairing or one addressed to someone',
    () async {
      final (attackerId, attacker) = await signedInUser('attacker');
      final (victimId, _) = await signedInUser('victim');

      for (final row in [
        {'status': 'active', 'recipient_id': victimId},
        {'status': 'pending', 'recipient_id': victimId},
        {'status': 'active'},
      ]) {
        await expectLater(
          attacker.from('pairings').insert({
            'requester_id': attackerId,
            'pairing_code': uniqueCode(),
            ...row,
          }),
          throwsA(isA<PostgrestException>()),
          reason: 'insert $row must be refused',
        );
      }

      expect(
          await admin
              .from('pairings')
              .select('id')
              .or('requester_id.eq.$victimId,recipient_id.eq.$victimId'),
          isEmpty);
    },
    tags: ['integration'],
    skip: skip,
  );

  test(
    'a requester can cancel their pending code but not activate it',
    () async {
      final (ownerId, owner) = await signedInUser('owner');
      final (victimId, _) = await signedInUser('victim');
      final code = uniqueCode();
      final row = await owner
          .from('pairings')
          .insert({
            'requester_id': ownerId,
            'pairing_code': code,
            'status': 'pending',
          })
          .select('id')
          .single();
      final id = row['id'] as String;

      await expectLater(
        owner.from('pairings').update(
            {'recipient_id': victimId, 'status': 'active'}).eq('id', id),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        owner.from('pairings').update({'status': 'active'}).eq('id', id),
        throwsA(isA<PostgrestException>()),
      );

      await owner.from('pairings').update({'status': 'cancelled'}).eq('id', id);
      final after = await admin.from('pairings').select().eq('id', id).single();
      expect(after['status'], 'cancelled');
      expect(after['recipient_id'], isNull);
    },
    tags: ['integration'],
    skip: skip,
  );

  test(
    'accept_pairing still activates a code after the guard',
    () async {
      final (ownerId, owner) = await signedInUser('owner');
      final (joinerId, joiner) = await signedInUser('joiner');
      final code = uniqueCode();
      await owner.from('pairings').insert({
        'requester_id': ownerId,
        'pairing_code': code,
        'status': 'pending',
      });

      await joiner.rpc('accept_pairing', params: {'p_code': code});

      final pairing = await admin
          .from('pairings')
          .select()
          .eq('pairing_code', code)
          .single();
      expect(pairing['status'], 'active');
      expect(pairing['recipient_id'], joinerId);
    },
    tags: ['integration'],
    skip: skip,
  );

  test(
    'nudges reach a partner but not a stranger',
    () async {
      final (aId, _) = await signedInUser('a');
      final (bId, b) = await signedInUser('b');
      final (cId, c) = await signedInUser('c');

      final pairing = await admin
          .from('pairings')
          .insert({
            'requester_id': aId,
            'recipient_id': bId,
            'pairing_code': uniqueCode(),
            'status': 'active',
          })
          .select('id')
          .single();
      final pairId = pairing['id'] as String;
      final task = await admin
          .from('tasks')
          .insert({
            'title': 'Nudge probe',
            'created_by_id': aId,
            'status': 'unclaimed',
            'priority': 'normal',
            'recurrence': 'none',
            'visibility': 'group',
            'pair_id': pairId,
          })
          .select('id')
          .single();
      final taskId = task['id'] as String;

      Map<String, dynamic> nudge(String from) => {
            'pair_id': pairId,
            'task_id': taskId,
            'from_user_id': from,
            'to_user_id': aId,
            'message': 'probe',
          };

      await expectLater(
        c.from('nudges').insert(nudge(cId)),
        throwsA(isA<PostgrestException>()),
      );
      await b.from('nudges').insert(nudge(bId));

      final received = await admin
          .from('nudges')
          .select('from_user_id')
          .eq('to_user_id', aId);
      expect(received, [
        {'from_user_id': bId}
      ]);
    },
    tags: ['integration'],
    skip: skip,
  );
}

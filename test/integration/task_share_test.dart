// Share links against a real Supabase project
// (migration 20261016000001_task_share_links.sql).
//
// The share RPCs are SECURITY DEFINER and two of them are open to anon, so
// these tests check what a stranger with (or without) a token can and can't
// do, and that claiming a link pairs the two people the way the pairing-code
// flow does.
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

  SupabaseClient anonClient() {
    final client = SupabaseClient(
      env!.url,
      env.anonKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    clients.add(client);
    return client;
  }

  /// Creates a confirmed disposable user and returns (userId, client).
  Future<(String, SupabaseClient)> signedInUser(String label,
      {String? displayName}) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final email = 'share-$label-$stamp@yopmail.com';
    final created = await admin.auth.admin.createUser(
      AdminUserAttributes(
        email: email,
        password: password,
        emailConfirm: true,
        userMetadata: {'display_name': displayName ?? email},
      ),
    );
    final id = created.user!.id;
    createdUserIds.add(id);

    // The on_auth_user_created trigger makes the profile; make sure the
    // display name is what this test expects.
    await admin.from('users').upsert(
      {
        'id': id,
        'email': email,
        'display_name': displayName ?? email,
        'pairing_code':
            'S${stamp.toString().substring(stamp.toString().length - 7)}',
      },
      onConflict: 'id',
    );

    final client = anonClient();
    await client.auth.signInWithPassword(email: email, password: password);
    return (id, client);
  }

  Future<String> createTask(String ownerId,
      {String visibility = 'personal', String recurrence = 'none'}) async {
    final row = await admin
        .from('tasks')
        .insert({
          'title': 'Pick up the dry cleaning',
          'description': 'Ticket is on the fridge',
          'created_by_id': ownerId,
          'status': 'unclaimed',
          'priority': 'urgent',
          'recurrence': recurrence,
          'visibility': visibility,
          'is_personal': visibility == 'personal',
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<String> shareToken(SupabaseClient owner, String taskId,
      {String? name}) async {
    final row = await owner.rpc('create_task_share', params: {
      'p_task_id': taskId,
      'p_recipient_name': name,
    });
    return (row as Map)['token'] as String;
  }

  Future<Map<String, dynamic>> task(String id) =>
      admin.from('tasks').select().eq('id', id).single();

  Matcher rpcError(String message) => throwsA(isA<PostgrestException>()
      .having((e) => e.message, 'message', contains(message)));

  setUpAll(() {
    if (env != null) admin = SupabaseClient(env.url, env.serviceRoleKey);
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
        // Already gone.
      }
    }
    createdUserIds.clear();
  });

  test(
    'only the owner can share, only shareable tasks, and the link is reused',
    () async {
      final (ownerId, owner) = await signedInUser('owner', displayName: 'Alex');
      final (_, outsider) = await signedInUser('outsider');
      final taskId = await createTask(ownerId);

      final first = await shareToken(owner, taskId, name: 'Sam');
      expect(first, matches(RegExp(r'^[A-Za-z0-9_-]{24}$')));
      expect(await shareToken(owner, taskId), first,
          reason: 'one live link per task');

      await expectLater(shareToken(outsider, taskId),
          rpcError('You can only share your own tasks'));
      await expectLater(
          anonClient().rpc('create_task_share', params: {'p_task_id': taskId}),
          throwsA(isA<PostgrestException>()));

      final groupTask = await createTask(ownerId, visibility: 'group');
      await expectLater(
          shareToken(owner, groupTask), rpcError('Only personal tasks'));
      final weekly = await createTask(ownerId, recurrence: 'weekly');
      await expectLater(shareToken(owner, weekly), rpcError('Repeating tasks'));
    },
    tags: ['integration'],
    skip: skip,
  );

  test(
    'a stranger with the token sees the task but nothing else',
    () async {
      final (ownerId, owner) =
          await signedInUser('owner'); // display name is an email
      final taskId = await createTask(ownerId);
      final token = await shareToken(owner, taskId, name: 'Sam');
      final anon = anonClient();

      final view = Map<String, dynamic>.from(
          await anon.rpc('get_shared_task', params: {'p_token': token}) as Map);
      expect(view['title'], 'Pick up the dry cleaning');
      expect(view['description'], 'Ticket is on the fridge');
      expect(view['priority'], 'urgent');
      expect(view['recipient_name'], 'Sam');
      expect(view['response'], 'pending');
      expect(view['sender_name'], isNull,
          reason: 'an email-shaped display name must not leak');
      expect(view.toString(), isNot(contains('@')));
      expect(view.keys, isNot(contains('task_id')));

      final row = await admin
          .from('task_shares')
          .select('open_count, first_opened_at')
          .eq('token', token)
          .single();
      expect(row['open_count'], 1);
      expect(row['first_opened_at'], isNotNull);

      // No direct table access for anon.
      await expectLater(anon.from('task_shares').select(),
          throwsA(isA<PostgrestException>()));
      expect(await anon.from('tasks').select().eq('id', taskId), isEmpty);

      await expectLater(
          anon.rpc('get_shared_task',
              params: {'p_token': 'AAAAAAAAAAAAAAAAAAAAAAAA'}),
          rpcError('link_not_found'));
      await expectLater(
          anon.rpc('get_shared_task', params: {'p_token': "x' or 1=1 --"}),
          rpcError('link_not_found'));
    },
    tags: ['integration'],
    skip: skip,
  );

  test(
    'the recipient can accept, finish, undo and decline without an account',
    () async {
      final (ownerId, owner) = await signedInUser('owner', displayName: 'Alex');
      final taskId = await createTask(ownerId);
      final token = await shareToken(owner, taskId);
      final anon = anonClient();

      Future<Map> respond(String action) async =>
          await anon.rpc('respond_to_shared_task',
              params: {'p_token': token, 'p_action': action}) as Map;

      var view = await respond('accept');
      expect(view['response'], 'accepted');
      expect(view['sender_name'], 'Alex');
      var t = await task(taskId);
      expect(t['status'], 'claimed');
      expect(t['claimed_by_id'], isNull);

      view = await respond('done');
      expect(view['response'], 'done');
      t = await task(taskId);
      expect(t['status'], 'completed');
      expect(t['completed_at'], isNotNull);

      view = await respond('undo');
      expect(view['response'], 'accepted');
      expect((await task(taskId))['status'], 'claimed');

      view = await respond('decline');
      expect(view['response'], 'declined');
      expect((await task(taskId))['status'], 'unclaimed');

      await expectLater(respond('delete'), rpcError('Unknown action'));

      // The owner finishing it locks the page's buttons out.
      await admin.from('tasks').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', taskId);
      view = await respond('accept');
      expect(view['task_status'], 'completed');
      expect((await task(taskId))['status'], 'completed');
    },
    tags: ['integration'],
    skip: skip,
  );

  test(
    'revoked and expired links stop working',
    () async {
      final (ownerId, owner) = await signedInUser('owner');
      final taskId = await createTask(ownerId);
      final anon = anonClient();

      final token = await shareToken(owner, taskId);
      await owner.rpc('revoke_task_share', params: {'p_task_id': taskId});
      await expectLater(anon.rpc('get_shared_task', params: {'p_token': token}),
          rpcError('link_revoked'));

      final fresh = await shareToken(owner, taskId);
      expect(fresh, isNot(token));
      await admin.from('task_shares').update({
        'expires_at':
            DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      }).eq('token', fresh);
      await expectLater(
          anon.rpc('respond_to_shared_task',
              params: {'p_token': fresh, 'p_action': 'done'}),
          rpcError('link_expired'));
      expect((await task(taskId))['status'], 'unclaimed');

      // Sharing again replaces the expired link.
      expect(await shareToken(owner, taskId), isNot(fresh));
    },
    tags: ['integration'],
    skip: skip,
  );

  test(
    'claiming a link pairs two unpaired people and moves the task over',
    () async {
      final (ownerId, owner) = await signedInUser('owner', displayName: 'Alex');
      final (newId, newUser) = await signedInUser('new', displayName: 'Sam');
      final (_, third) = await signedInUser('third');
      final taskId = await createTask(ownerId);
      final token = await shareToken(owner, taskId);

      await anonClient().rpc('respond_to_shared_task',
          params: {'p_token': token, 'p_action': 'accept'});

      await expectLater(
          owner.rpc('claim_task_share', params: {'p_token': token}),
          rpcError('own_link'));

      final result = Map<String, dynamic>.from(await newUser
          .rpc('claim_task_share', params: {'p_token': token}) as Map);
      expect(result['paired'], isTrue);
      expect(result['sender_name'], 'Alex');
      expect(result['task_id'], taskId);

      final pairing = await admin
          .from('pairings')
          .select()
          .eq('requester_id', ownerId)
          .eq('recipient_id', newId)
          .eq('status', 'active')
          .single();
      final users = await admin
          .from('users')
          .select('id, paired_with_id')
          .inFilter('id', [ownerId, newId]);
      for (final u in users) {
        expect(u['paired_with_id'], u['id'] == ownerId ? newId : ownerId);
      }

      final t = await task(taskId);
      expect(t['visibility'], 'group');
      expect(t['pair_id'], pairing['id']);
      expect(t['assigned_to_id'], newId);
      expect(t['claimed_by_id'], newId,
          reason: 'they had said "I\'ll do it" on the page');

      // The new account sees the task and can finish it (ownership lock).
      expect(await newUser.from('tasks').select('id').eq('id', taskId),
          hasLength(1));
      final cycled = await newUser
          .rpc('cycle_task_status',
              params: {'task_uuid': taskId, 'user_uuid': newId})
          .select()
          .single();
      expect(cycled['status'], 'completed');

      // Claiming again is harmless; someone else can't.
      final again = await newUser
          .rpc('claim_task_share', params: {'p_token': token}) as Map;
      expect(again['paired'], isTrue);
      await expectLater(
          third.rpc('claim_task_share', params: {'p_token': token}),
          rpcError('already_claimed'));
      expect(
          await admin
              .from('pairings')
              .select('id')
              .eq('status', 'active')
              .or('requester_id.eq.$newId,recipient_id.eq.$newId'),
          hasLength(1));
    },
    tags: ['integration'],
    skip: skip,
  );

  test(
    'claiming when the sender is already paired just hands over the task',
    () async {
      final (ownerId, owner) = await signedInUser('owner', displayName: 'Alex');
      final (partnerId, _) = await signedInUser('partner');
      final (newId, newUser) = await signedInUser('helper');
      await admin.from('pairings').insert({
        'requester_id': ownerId,
        'recipient_id': partnerId,
        'pairing_code': 'P${DateTime.now().millisecond}XYZ',
        'status': 'active',
      });
      final taskId = await createTask(ownerId);
      final token = await shareToken(owner, taskId);

      final result = await newUser
          .rpc('claim_task_share', params: {'p_token': token}) as Map;
      expect(result['paired'], isFalse);

      final t = await task(taskId);
      expect(t['visibility'], 'personal');
      expect(t['assigned_to_id'], newId);
      expect(await newUser.from('tasks').select('id').eq('id', taskId),
          hasLength(1));
      expect(
          await admin
              .from('pairings')
              .select('id')
              .or('requester_id.eq.$newId,recipient_id.eq.$newId'),
          isEmpty);
    },
    tags: ['integration'],
    skip: skip,
  );
}

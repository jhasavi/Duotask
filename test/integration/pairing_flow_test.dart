// End-to-end pairing test against a real Supabase project.
//
// This replaces the manual checklist that PAIRING_TEST_GUIDE.md and
// PROJECT_STATUS.md described as a release gate ("pair two users and verify
// bidirectional visibility", "create personal vs group tasks"). Those steps
// required two humans with two browsers and were, in practice, never run —
// which is how the app shipped with pairing regressions.
//
// Credentials come from the environment; see test/support/integration_env.dart.
// This creates and deletes real auth users, so point it at a dedicated test
// project, never production.
//
// Run with: flutter test --tags integration
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duotask/services/pairing_service.dart';
import 'package:duotask/services/task_service.dart';
import 'package:duotask/models/task.dart';

import '../support/integration_env.dart';

void main() {
  final env = IntegrationEnv.tryLoad();
  final skip = env == null ? IntegrationEnv.skipReason : null;

  late SupabaseClient admin;
  final createdUserIds = <String>[];

  /// Creates a confirmed disposable user and returns its id.
  Future<String> createUser(String label) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final created = await admin.auth.admin.createUser(
      AdminUserAttributes(
        email: 'pair-$label-$stamp@yopmail.com',
        password: 'TestPassword123!',
        emailConfirm: true,
        userMetadata: {'display_name': 'Pair Test $label'},
      ),
    );
    final id = created.user!.id;
    createdUserIds.add(id);

    // A DB trigger normally creates the profile row; make sure one exists
    // either way so the pairing queries have something to join against.
    await admin.from('users').upsert(
      {
        'id': id,
        'email': created.user!.email,
        'display_name': 'Pair Test $label',
        'pairing_code':
            'T${stamp.toString().substring(stamp.toString().length - 7)}',
      },
      onConflict: 'id',
    );

    return id;
  }

  setUpAll(() {
    if (env != null) {
      admin = SupabaseClient(env.url, env.serviceRoleKey);
    }
  });

  tearDown(() async {
    if (env == null) return;
    for (final id in createdUserIds) {
      await admin.from('pairings').delete().eq('requester_id', id);
      await admin.from('pairings').delete().eq('recipient_id', id);
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
    'two users can pair via a code and both see the active pairing',
    () async {
      final userA = await createUser('a');
      final userB = await createUser('b');

      final serviceA = PairingService(admin);
      final serviceB = PairingService(admin);

      // A generates a code.
      final code = await serviceA.createPairingCode(userA);
      expect(
        code,
        isNotNull,
        reason: 'createPairingCode failed: ${serviceA.errorMessage}',
      );
      expect(code!.length, 8, reason: 'pairing codes are 8 characters');

      // B accepts it.
      final accepted = await serviceB.acceptPairingCode(userB, code);
      expect(
        accepted,
        isTrue,
        reason: 'acceptPairingCode failed: ${serviceB.errorMessage}',
      );

      // Both sides must independently observe the active pairing — this is the
      // "bidirectional visibility" the manual guide asked a human to eyeball.
      await serviceA.checkPairingStatus(userA);
      await serviceB.checkPairingStatus(userB);

      expect(serviceA.isPaired, isTrue,
          reason: 'requester does not see pairing');
      expect(serviceB.isPaired, isTrue,
          reason: 'recipient does not see pairing');
      expect(serviceA.partner?.id, userB, reason: 'A has the wrong partner');
      expect(serviceB.partner?.id, userA, reason: 'B has the wrong partner');
    },
    tags: ['integration'],
    skip: skip,
  );

  test(
    'an already-used pairing code cannot be redeemed twice',
    () async {
      final userA = await createUser('a');
      final userB = await createUser('b');
      final userC = await createUser('c');

      final serviceA = PairingService(admin);
      final code = await serviceA.createPairingCode(userA);
      expect(code, isNotNull);

      expect(
          await PairingService(admin).acceptPairingCode(userB, code!), isTrue);

      // C tries the same code after B consumed it.
      final serviceC = PairingService(admin);
      final reused = await serviceC.acceptPairingCode(userC, code);
      expect(
        reused,
        isFalse,
        reason: 'a consumed pairing code must not pair a third user',
      );
    },
    tags: ['integration'],
    skip: skip,
  );

  test(
    'unpairing clears the partner for both users',
    () async {
      final userA = await createUser('a');
      final userB = await createUser('b');

      final serviceA = PairingService(admin);
      final serviceB = PairingService(admin);

      final code = await serviceA.createPairingCode(userA);
      expect(await serviceB.acceptPairingCode(userB, code!), isTrue);

      expect(
        await serviceA.unpair(userA),
        isTrue,
        reason: 'unpair failed: ${serviceA.errorMessage}',
      );

      await serviceA.checkPairingStatus(userA);
      await serviceB.checkPairingStatus(userB);

      expect(serviceA.isPaired, isFalse, reason: 'A still shows as paired');
      expect(serviceB.isPaired, isFalse, reason: 'B still shows as paired');
    },
    tags: ['integration'],
    skip: skip,
  );

  test(
    'a paired task created by one user is visible to the other',
    () async {
      final userA = await createUser('a');
      final userB = await createUser('b');

      final serviceA = PairingService(admin);
      final serviceB = PairingService(admin);
      final code = await serviceA.createPairingCode(userA);
      expect(await serviceB.acceptPairingCode(userB, code!), isTrue);
      await serviceA.checkPairingStatus(userA);

      final tasksA = TaskService(admin);
      final created = await tasksA.createTask(
        title: 'Shared groceries',
        userId: userA,
        assignedToId: userB,
        visibility: TaskVisibility.group,
      );
      expect(
        created,
        isNotNull,
        reason: 'createTask failed: ${tasksA.errorMessage}',
      );

      final tasksB = TaskService(admin);
      await tasksB.loadTasks(userB);

      expect(
        tasksB.tasks.map((t) => t.id),
        contains(created!.id),
        reason: 'partner cannot see the shared task',
      );
    },
    tags: ['integration'],
    skip: skip,
  );
}

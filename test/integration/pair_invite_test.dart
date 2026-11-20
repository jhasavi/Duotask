// Partner invite links (migration 20261115000001_pair_invite_links.sql)
// against a real Supabase project: an anonymous visitor sees the inviter's
// first name, signing in with a stored invite pairs the two of you, and an
// already-paired user isn't paired twice.
//
// Run with: flutter test --tags integration
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:evenhalf/models/pair_invite.dart';
import 'package:evenhalf/services/pairing_service.dart';

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
    final email = 'invite-$label-$stamp@yopmail.com';
    final created = await admin.auth.admin.createUser(
      AdminUserAttributes(
        email: email,
        password: password,
        emailConfirm: true,
        userMetadata: {'display_name': 'Invitee$label Test'},
      ),
    );
    final id = created.user!.id;
    createdUserIds.add(id);
    await admin.from('users').upsert(
      {
        'id': id,
        'email': email,
        'display_name': 'Invitee$label Test',
        'pairing_code':
            'I${stamp.toString().substring(stamp.toString().length - 7)}',
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

  test('an anonymous visitor sees only the inviter\'s first name', skip: skip,
      () async {
    final (aId, aClient) = await signedInUser('Ann');
    final code = await PairingService(aClient).createPairingCode(aId);
    expect(code, isNotNull);

    final anon = SupabaseClient(env!.url, env.anonKey);
    addTearDown(anon.dispose);
    expect(
      await anon.rpc('pair_invite_preview', params: {'p_code': code}),
      'InviteeAnn',
    );
    expect(
      await anon.rpc('pair_invite_preview', params: {'p_code': 'NOPE0000'}),
      isNull,
    );
    expect(
      await anon.rpc('pair_invite_preview', params: {'p_code': "'; drop"}),
      isNull,
    );
  });

  test('signing in with a stored invite pairs the two users', skip: skip,
      () async {
    final (aId, aClient) = await signedInUser('Bea');
    final (bId, bClient) = await signedInUser('Cal');
    final code = await PairingService(aClient).createPairingCode(aId);

    SharedPreferences.setMockInitialValues({PairInvite.pendingKey: code!});
    final b = PairingService(bClient);
    final outcome = await b.claimPendingInvite(bId);
    b.dispose();

    expect(outcome?.paired, isTrue, reason: outcome?.message);
    expect(await PairInvite.pending(), isNull);
    final bRow = await admin
        .from('users')
        .select('paired_with_id')
        .eq('id', bId)
        .single();
    expect(bRow['paired_with_id'], aId);
  });

  test('an already-paired user is not paired a second time', skip: skip,
      () async {
    final (aId, aClient) = await signedInUser('Dee');
    final (bId, bClient) = await signedInUser('Eli');
    final (cId, cClient) = await signedInUser('Fay');

    final b = PairingService(bClient);
    final aCode = await PairingService(aClient).createPairingCode(aId);
    expect(await b.acceptPairingCode(bId, aCode!), isTrue);

    final cCode = await PairingService(cClient).createPairingCode(cId);
    SharedPreferences.setMockInitialValues({PairInvite.pendingKey: cCode!});
    final outcome = await b.claimPendingInvite(bId);
    b.dispose();

    expect(outcome?.paired, isFalse);
    expect(outcome?.message, contains('already paired'));
    final cPending = await admin
        .from('pairings')
        .select('status')
        .eq('pairing_code', cCode)
        .single();
    expect(cPending['status'], 'pending', reason: "C's invite stays unused");
  });

  test('logging a sent invite works and rejects unknown channels', skip: skip,
      () async {
    final (aId, aClient) = await signedInUser('Gus');
    await PairingService(aClient).createPairingCode(aId);
    await aClient
        .rpc('log_pair_invite_sent', params: {'p_channel': 'whatsapp'});
    await expectLater(
      aClient.rpc('log_pair_invite_sent', params: {'p_channel': 'pigeon'}),
      throwsA(isA<PostgrestException>()
          .having((e) => e.message, 'message', contains('invalid_channel'))),
    );
  });
}

// Lifecycle email selection (migration 20261115000003_lifecycle_emails.sql)
// against a real Supabase project: who gets which email, when, and only
// once. The edge function that sends them is a thin loop over these RPCs.
//
// Creates and deletes real auth users; use a dedicated test project. Claims
// due emails for every user in the project, so don't point it at production.
// Run with: flutter test --tags integration
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/integration_env.dart';

/// An Etc/GMT zone where the local hour is [hour] right now. (Etc/GMT signs
/// are inverted: Etc/GMT-5 is UTC+5.)
String zoneAtLocalHour(int hour) {
  var offset = hour - DateTime.now().toUtc().hour;
  if (offset > 14) offset -= 24;
  if (offset < -12) offset += 24;
  if (offset == 0) return 'UTC';
  return offset > 0 ? 'Etc/GMT-$offset' : 'Etc/GMT+${-offset}';
}

void main() {
  final env = IntegrationEnv.tryLoad();
  final skip = env == null ? IntegrationEnv.skipReason : null;

  late SupabaseClient admin;
  final createdUserIds = <String>[];

  /// A user who signed up [age] ago, with email preferences in [zone].
  Future<String> user(
    String label, {
    required Duration age,
    String? zone,
    bool optedIn = true,
  }) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final email = 'life-$label-$stamp@yopmail.com';
    final created = await admin.auth.admin.createUser(AdminUserAttributes(
      email: email,
      password: 'TestPassword123!',
      emailConfirm: true,
    ));
    final id = created.user!.id;
    createdUserIds.add(id);
    await admin.from('users').upsert({
      'id': id,
      'email': email,
      'display_name': 'Life $label',
      'pairing_code':
          'L${stamp.toString().substring(stamp.toString().length - 7)}',
      'created_at': DateTime.now().toUtc().subtract(age).toIso8601String(),
    }, onConflict: 'id');
    await admin.from('email_preferences').upsert({
      'user_id': id,
      'timezone': zone ?? zoneAtLocalHour(12),
      'lifecycle_emails_enabled': optedIn,
    });
    return id;
  }

  /// Claims due emails and returns {userId: kind} for this test's users.
  Future<Map<String, String>> claim() async {
    final rows = await admin.rpc('claim_lifecycle_emails') as List;
    return {
      for (final r in rows.cast<Map<String, dynamic>>())
        if (createdUserIds.contains(r['user_id']))
          r['user_id'] as String: r['kind'] as String,
    };
  }

  Future<List<Map<String, dynamic>>> claimRows() async =>
      (await admin.rpc('claim_lifecycle_emails') as List)
          .cast<Map<String, dynamic>>()
          .where((r) => createdUserIds.contains(r['user_id']))
          .toList();

  Future<void> finishAll(List<Map<String, dynamic>> rows,
      {required bool sent}) async {
    for (final r in rows) {
      await admin.rpc('finish_lifecycle_email',
          params: {'p_email_id': r['email_id'], 'p_sent': sent});
    }
  }

  setUpAll(() {
    if (env == null) return;
    admin = SupabaseClient(env.url, env.serviceRoleKey);
  });

  tearDown(() async {
    if (env == null) return;
    for (final id in createdUserIds) {
      try {
        await admin.auth.admin.deleteUser(id);
      } catch (_) {}
    }
    createdUserIds.clear();
  });

  test('picks the right email by age and pairing, one per user', skip: skip,
      () async {
    final day2 = await user('day2', age: const Duration(days: 2));
    final day4 = await user('day4', age: const Duration(days: 4));
    final day4Paired = await user('day4p', age: const Duration(days: 4));
    final partner = await user('partner', age: const Duration(hours: 1));
    await admin
        .from('users')
        .update({'paired_with_id': partner}).eq('id', day4Paired);
    final fresh = await user('fresh', age: const Duration(hours: 2));
    final old = await user('old', age: const Duration(days: 30));

    final claimed = await claim();

    expect(claimed[day2], 'invite_partner');
    expect(claimed[day4], 'invite_partner',
        reason: 'unpaired: the invite comes first, tips later');
    expect(claimed[day4Paired], 'tips');
    expect(claimed.containsKey(fresh), isFalse, reason: 'under a day old');
    expect(claimed.containsKey(old), isFalse,
        reason: 'signed up long ago: no surprise emails');
    expect(claimed.containsKey(partner), isFalse);
  });

  test('a sent email is never sent again, and the next waits 20 hours',
      skip: skip, () async {
    final id = await user('once', age: const Duration(days: 4));

    final first = await claimRows();
    expect(first.single['kind'], 'invite_partner');
    await finishAll(first, sent: true);

    expect(await claim(), isEmpty,
        reason: 'tips is due too, but not within 20h of the invite');

    // Pretend the invite went out yesterday morning.
    await admin.from('lifecycle_emails').update({
      'sent_at': DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 21))
          .toIso8601String()
    }).eq('user_id', id);
    expect((await claim())[id], 'tips');
  });

  test('a failed send is retried, up to three attempts', skip: skip, () async {
    await user('flaky', age: const Duration(days: 2));

    for (var attempt = 1; attempt <= 3; attempt++) {
      final rows = await claimRows();
      expect(rows, hasLength(1), reason: 'attempt $attempt');
      await finishAll(rows, sent: false);
    }
    expect(await claim(), isEmpty, reason: 'gives up after three');
  });

  test('two overlapping runs cannot claim the same email', skip: skip,
      () async {
    await user('race', age: const Duration(days: 2));
    final results = await Future.wait([claimRows(), claimRows()]);
    expect(results[0].length + results[1].length, 1);
  });

  test('only during the day in the user\'s timezone', skip: skip, () async {
    final night = await user('night',
        age: const Duration(days: 2), zone: zoneAtLocalHour(3));
    final day = await user('day', age: const Duration(days: 2));
    final claimed = await claim();
    expect(claimed.containsKey(night), isFalse);
    expect(claimed[day], 'invite_partner');
  });

  test('opting out stops onboarding emails but not the trial notice',
      skip: skip, () async {
    final out = await user('out', age: const Duration(days: 2), optedIn: false);
    final trial =
        await user('trial', age: const Duration(days: 2), optedIn: false);
    await admin.from('users').update({
      'is_premium': true,
      'premium_until':
          DateTime.now().toUtc().add(const Duration(days: 2)).toIso8601String(),
    }).eq('id', trial);
    await admin.from('billing_customers').upsert({
      'user_id': trial,
      'stripe_customer_id': 'cus_test_${DateTime.now().microsecondsSinceEpoch}',
      'subscription_status': 'trialing',
    });

    final rows = await claimRows();
    final byUser = {for (final r in rows) r['user_id']: r};
    expect(byUser.containsKey(out), isFalse);
    expect(byUser[trial]?['kind'], 'trial_ending');
    expect(byUser[trial]?['trial_ends_at'], isNotNull);
  });

  test('clients cannot call the claim RPC', skip: skip, () async {
    final anon = SupabaseClient(env!.url, env.anonKey);
    addTearDown(anon.dispose);
    await expectLater(
      anon.rpc('claim_lifecycle_emails'),
      throwsA(isA<PostgrestException>()),
    );
  });
}

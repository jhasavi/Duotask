// Integration test against the REAL live Supabase project (not mocked).
//
// Reproduces the exact original race condition: AuthService's own
// _initAuthListener() fires _loadCurrentUser() in the background the moment
// a session appears, at the same time the explicit sign-in/sign-up call
// awaits _loadCurrentUser() itself. Before the fix, both concurrent calls
// would see "no profile row yet" for a user's FIRST-ever session, both try
// to INSERT the same primary key, and the loser's duplicate-key error got
// treated as fatal and signed the user back out.
//
// This project requires email confirmation, so plain signUp() never yields
// an immediate session — the race instead fires on first sign-in for any
// account with no profile row yet (which is exactly what admin.createUser
// produces, and is the same underlying trigger: a user's first-ever
// session with no `users` row). We admin-create a confirmed disposable user,
// then drive the app's real signInWithEmail() against it.
//
// Run with: flutter test test/integration/signup_race_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duotask/services/auth_service.dart';

// Same project the app actually uses (public URL + anon key, safe to embed —
// these are client-side credentials by design, gated by RLS not secrecy).
const _url = 'https://xqhlnuvpogiolzkucupt.supabase.co';
const _anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhxaGxudXZwb2dpb2x6a3VjdXB0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE5MTA1NzgsImV4cCI6MjA2NzQ4NjU3OH0.9lw-X6mjpPFfTqpiiTEOpzWZEfqnPkW0ADA6XfbLsNw';
// Service-role key: used ONLY to admin-create/confirm and later delete the
// disposable test user this test creates. Never used by the app itself.
const _serviceRoleKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhxaGxudXZwb2dpb2x6a3VjdXB0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTkxMDU3OCwiZXhwIjoyMDY3NDg2NTc4fQ.qV_Ewz2hh_Xyq1mOPXjUr6FrI_02U1-mc6VO_ql-Yps';

void main() {
  test(
    'first sign-in survives the auth-listener / explicit-load race without '
    'being signed back out (regression test for the duplicate-key bug)',
    () async {
      final admin = SupabaseClient(_url, _serviceRoleKey);
      // authFlowType: implicit — the app itself relies on Supabase.initialize()
      // to supply PKCE storage; a bare SupabaseClient here has none, and
      // email/password auth doesn't need PKCE (that's for OAuth/magic links).
      final client = SupabaseClient(
        _url,
        _anonKey,
        authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      );

      final stamp = DateTime.now().millisecondsSinceEpoch;
      final email = 'race-test-$stamp@yopmail.com';
      const password = 'TestPassword123!';
      String? userId;

      try {
        final created = await admin.auth.admin.createUser(
          AdminUserAttributes(
            email: email,
            password: password,
            emailConfirm: true,
            userMetadata: {'display_name': 'Race Test User'},
          ),
        );
        userId = created.user?.id;
        expect(userId, isNotNull, reason: 'admin.createUser did not return a user');

        // Discovery made while writing this test: a database trigger (not
        // present anywhere in this repo's migrations — see PROJECT_STATUS.md
        // notes on schema drift) already auto-creates the `users` profile row
        // transactionally when the `auth.users` row is inserted. That means
        // by the time any client sees a session, the row already exists, and
        // _loadCurrentUser() never reaches the INSERT/upsert branch through
        // this path — the app-level race this test targets is naturally hard
        // to hit here. Deleting the trigger-created row recreates the exact
        // precondition (first-ever session, no profile row) that the
        // original bug needed, so this test still directly exercises the
        // app-level fix regardless of whether the DB-side trigger is present,
        // gets modified, or fails in some future migration.
        await admin.from('users').delete().eq('id', userId!);
        final before = await admin.from('users').select().eq('id', userId);
        expect(before, isEmpty,
            reason: 'test setup invalid: a profile row still exists after delete');

        final authService = AuthService(client);
        final ok = await authService.signInWithEmail(email, password);

        expect(
          ok,
          isTrue,
          reason: 'signInWithEmail returned false: '
              '${authService.errorMessage}',
        );
        expect(
          authService.isAuthenticated,
          isTrue,
          reason: 'user was signed out — the race condition reproduced. '
              'error: ${authService.errorMessage}',
        );
        expect(authService.currentUser, isNotNull);
        expect(authService.currentUser!.email, email);
        expect(authService.currentUser!.id, userId);

        // Confirm exactly one profile row exists — not zero (insert never
        // happened) and the query itself didn't error with a duplicate key.
        final rows = await admin.from('users').select().eq('id', userId);
        expect(
          rows.length,
          1,
          reason: 'expected exactly one profile row, found ${rows.length}',
        );
      } finally {
        if (userId != null) {
          await admin.from('users').delete().eq('id', userId);
          await admin.auth.admin.deleteUser(userId);
        }
      }
    },
  );
}

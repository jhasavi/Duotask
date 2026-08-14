// Credential plumbing for tests that talk to a real Supabase project.
//
// Nothing in here may ever hold a literal key. Integration tests read their
// credentials from the environment, and skip themselves when it is absent, so
// that a plain `flutter test` stays hermetic and never touches a live project.
//
// Supply values either as process environment variables or via --dart-define:
//
//   export SUPABASE_TEST_URL=https://<test-project>.supabase.co
//   export SUPABASE_TEST_ANON_KEY=...
//   export SUPABASE_TEST_SERVICE_ROLE_KEY=...
//   flutter test --tags integration
//
// Point these at a DEDICATED test project, never at production: these tests
// create and delete real auth users.
import 'dart:io';

class IntegrationEnv {
  const IntegrationEnv._(this.url, this.anonKey, this.serviceRoleKey);

  final String url;
  final String anonKey;
  final String serviceRoleKey;

  static String _read(String name, String dartDefine) {
    final fromProcess = Platform.environment[name];
    if (fromProcess != null && fromProcess.isNotEmpty) return fromProcess;
    return dartDefine;
  }

  /// Returns null when credentials are not configured, which callers should
  /// treat as "skip this test" rather than as a failure.
  static IntegrationEnv? tryLoad() {
    final url = _read('SUPABASE_TEST_URL',
        const String.fromEnvironment('SUPABASE_TEST_URL'),);
    final anonKey = _read('SUPABASE_TEST_ANON_KEY',
        const String.fromEnvironment('SUPABASE_TEST_ANON_KEY'),);
    final serviceRoleKey = _read('SUPABASE_TEST_SERVICE_ROLE_KEY',
        const String.fromEnvironment('SUPABASE_TEST_SERVICE_ROLE_KEY'),);

    if (url.isEmpty || anonKey.isEmpty || serviceRoleKey.isEmpty) return null;
    return IntegrationEnv._(url, anonKey, serviceRoleKey);
  }

  static const skipReason =
      'Integration credentials not configured. Set SUPABASE_TEST_URL, '
      'SUPABASE_TEST_ANON_KEY and SUPABASE_TEST_SERVICE_ROLE_KEY (pointing at '
      'a dedicated test project) to run this suite.';
}

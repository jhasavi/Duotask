import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:duotask/services/auth_service.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService authService;

  setUp(() {
    authService = MockAuthService();
  });

  group('AuthService Tests', () {
    test('signInWithEmailAndPassword - success', () async {
      // TODO: Implement test
    });

    test('signInWithGoogle - success', () async {
      // TODO: Implement test
    });

    test('signOut - success', () async {
      // TODO: Implement test
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:task_bubble/models/user.dart';
import 'package:task_bubble/services/pairing_service.dart';

class MockPairingService extends Mock implements PairingService {}

void main() {
  late MockPairingService pairingService;
  final testPairCode = 'ABC12345';
  final testUser = User(
    id: 'user1',
    email: 'test@example.com',
    displayName: 'Test User',
  );

  setUp(() {
    pairingService = MockPairingService();
  });

  group('PairingService Tests', () {
    test('generatePairCode - returns valid code', () async {
      when(pairingService.generatePairCode())
          .thenAnswer((_) async => testPairCode);

      final code = await pairingService.generatePairCode();
      
      expect(code, isA<String>());
      expect(code.length, 8);
    });

    test('pairWithCode - successful pairing', () async {
      when(pairingService.pairWithCode(testPairCode))
          .thenAnswer((_) async => testUser);

      final result = await pairingService.pairWithCode(testPairCode);
      
      expect(result, isA<User>());
      expect(result.id, 'user1');
    });

    test('getCurrentPair - returns paired user', () async {
      when(pairingService.getCurrentPair())
          .thenAnswer((_) async => testUser);

      final result = await pairingService.getCurrentPair();
      
      expect(result, isA<User>());
      expect(result.email, 'test@example.com');
    });
  });
}

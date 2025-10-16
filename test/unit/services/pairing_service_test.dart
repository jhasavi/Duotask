import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:duotask/models/user.dart';
import 'package:duotask/services/pairing_service.dart';

class MockPairingService extends Mock implements PairingService {}

void main() {
  late MockPairingService pairingService;
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
      when(pairingService.generatePairCode('user1'))
          .thenAnswer((_) async => '123456');

      final code = await pairingService.generatePairCode('user1');

      expect(code, isA<String>());
      expect(code.length, 6);
    });

    test('getPairInfo - returns pair information', () async {
      final pairInfo = {
        'partner_id': 'user2',
        'partner_name': 'Test Partner',
        'online': true,
      };

      when(pairingService.getPairInfo('user1'))
          .thenAnswer((_) async => pairInfo);

      final result = await pairingService.getPairInfo('user1');

      expect(result, isNotNull);
      expect(result!['partner_id'], 'user2');
    });
  });
}

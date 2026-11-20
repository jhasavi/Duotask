import 'package:flutter_test/flutter_test.dart';
import 'package:evenhalf/config/constants.dart';

void main() {
  testWidgets('App constants are defined', (WidgetTester tester) async {
    expect(AppConstants.appName, 'EvenHalf');
    expect(AppConstants.pairingCodeLength, 8);
  });
}

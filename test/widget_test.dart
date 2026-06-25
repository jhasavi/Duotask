import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duotask/config/constants.dart';

void main() {
  testWidgets('App constants are defined', (WidgetTester tester) async {
    expect(AppConstants.appName, 'DuoTask');
    expect(AppConstants.pairingCodeLength, 8);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TaskList placeholder test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Task List Placeholder'),
        ),
      ),
    );

    expect(find.text('Task List Placeholder'), findsOneWidget);
  });
}

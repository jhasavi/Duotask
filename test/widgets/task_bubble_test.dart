import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duotask/models/task.dart';
import 'package:duotask/widgets/task_bubble.dart';

import '../test_helpers.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('announces title, status and priority to screen readers',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(TaskBubble(
      task: TestData.mockTask(
        title: 'Book sitter',
        status: TaskStatus.claimed,
        priority: TaskPriority.urgent,
      ),
      isCreatedByPartner: false,
      claimerInitials: 'SJ',
      onTap: () {},
    )));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Book sitter, claimed by SJ, urgent'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a rapid double tap fires onTap once', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(TaskBubble(
      task: TestData.mockTask(status: TaskStatus.claimed),
      isCreatedByPartner: false,
      onTap: () => taps++,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TaskBubble));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.tap(find.byType(TaskBubble));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });
}

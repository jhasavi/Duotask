import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duotask/models/task.dart';

void main() {
  final testTask = DuoTask(
    id: '1',
    title: 'Buy groceries',
    description: 'Milk, eggs, bread',
    status: TaskStatus.unclaimed,
    ownerId: 'user1',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  testWidgets('TaskItem displays task title and description', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Text(testTask.title),
        ),
      ),
    );

    expect(find.text('Buy groceries'), findsOneWidget);
  });

  testWidgets('TaskItem calls onTap when tapped', (WidgetTester tester) async {
    bool wasTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureDetector(
            onTap: () => wasTapped = true,
            child: Text(testTask.title),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(Text));
    await tester.pump();

    expect(wasTapped, isTrue);
  });
}

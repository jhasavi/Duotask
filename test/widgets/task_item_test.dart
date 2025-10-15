import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_bubble/models/task.dart';
import 'package:task_bubble/widgets/task_item.dart';

void main() {
  final testTask = Task(
    id: '1',
    title: 'Buy groceries',
    description: 'Milk, eggs, bread',
    status: TaskStatus.pending,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  testWidgets('TaskItem displays task title and description', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskItem(
            task: testTask,
            onTap: () {},
            onStatusChanged: (status) {},
          ),
        ),
      ),
    );

    expect(find.text('Buy groceries'), findsOneWidget);
    expect(find.text('Milk, eggs, bread'), findsOneWidget);
  });

  testWidgets('TaskItem calls onTap when tapped', (WidgetTester tester) async {
    bool wasTapped = false;
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskItem(
            task: testTask,
            onTap: () => wasTapped = true,
            onStatusChanged: (status) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TaskItem));
    await tester.pump();
    
    expect(wasTapped, isTrue);
  });
}

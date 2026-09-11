import 'package:flutter_test/flutter_test.dart';
import 'package:duotask/models/task.dart';
import 'package:duotask/utils/task_sort.dart';

void main() {
  group('sortTasksForDisplay', () {
    test('sorts urgent tasks before normal tasks', () {
      final tasks = [
        Task(
          id: '1',
          title: 'Normal',
          createdById: 'u1',
          status: TaskStatus.unclaimed,
          priority: TaskPriority.normal,
          recurrence: TaskRecurrence.none,
          createdAt: DateTime(2026, 1, 1),
        ),
        Task(
          id: '2',
          title: 'Urgent',
          createdById: 'u1',
          status: TaskStatus.unclaimed,
          priority: TaskPriority.urgent,
          recurrence: TaskRecurrence.none,
          createdAt: DateTime(2026, 1, 2),
        ),
      ];

      final sorted = sortTasksForDisplay(tasks);
      expect(sorted.first.priority, TaskPriority.urgent);
    });
  });

  group('taskMatchesSearch', () {
    test('matches case-insensitive title search', () {
      final task = Task(
        id: '1',
        title: 'Buy Groceries',
        createdById: 'u1',
        status: TaskStatus.unclaimed,
        priority: TaskPriority.normal,
        recurrence: TaskRecurrence.none,
        createdAt: DateTime.now(),
      );

      expect(taskMatchesSearch(task, 'grocer'), isTrue);
      expect(taskMatchesSearch(task, 'laundry'), isFalse);
    });

    test('also matches against tags', () {
      final task = Task(
        id: '1',
        title: 'Buy Groceries',
        createdById: 'u1',
        status: TaskStatus.unclaimed,
        priority: TaskPriority.normal,
        recurrence: TaskRecurrence.none,
        createdAt: DateTime.now(),
        tags: const ['home', 'urgent'],
      );

      expect(taskMatchesSearch(task, 'home'), isTrue);
      expect(taskMatchesSearch(task, 'work'), isFalse);
    });
  });

  group('taskMatchesTag', () {
    final task = Task(
      id: '1',
      title: 'Task',
      createdById: 'u1',
      status: TaskStatus.unclaimed,
      priority: TaskPriority.normal,
      recurrence: TaskRecurrence.none,
      createdAt: DateTime.now(),
      tags: const ['home'],
    );

    test('returns true when no tag filter is set', () {
      expect(taskMatchesTag(task, null), isTrue);
    });

    test('returns true when task has the filtered tag', () {
      expect(taskMatchesTag(task, 'home'), isTrue);
    });

    test('returns false when task lacks the filtered tag', () {
      expect(taskMatchesTag(task, 'work'), isFalse);
    });
  });

  group('taskMatchesTodayFilter', () {
    test('returns true when filter is off', () {
      final task = Task(
        id: '1',
        title: 'Task',
        createdById: 'u1',
        status: TaskStatus.unclaimed,
        priority: TaskPriority.normal,
        recurrence: TaskRecurrence.none,
        createdAt: DateTime.now(),
      );

      expect(taskMatchesTodayFilter(task, false), isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:duotask/models/task.dart';

void main() {
  group('Task Model Tests', () {
    test('Task should be created with correct properties', () {
      final task = Task(
        id: '1',
        title: 'Test Task',
        description: 'Test Description',
        createdById: 'user1',
        status: TaskStatus.unclaimed,
        priority: TaskPriority.normal,
        recurrence: TaskRecurrence.none,
        createdAt: DateTime.now(),
        isPersonal: false,
      );

      expect(task.id, '1');
      expect(task.title, 'Test Task');
      expect(task.status, TaskStatus.unclaimed);
      expect(task.priority, TaskPriority.normal);
    });

    test('due date is sent as UTC and read back as the same local time', () {
      // Postgres timestamptz reads an offset-less string as UTC, so a local
      // 6pm sent without one came back as 6pm UTC (2pm in New York).
      final dueLocal = DateTime(2026, 10, 31, 18);
      final task = Task(
        id: '1',
        title: 'Pick up dry cleaning',
        createdById: 'user1',
        status: TaskStatus.unclaimed,
        priority: TaskPriority.urgent,
        recurrence: TaskRecurrence.none,
        createdAt: DateTime.now(),
        dueDate: dueLocal,
        isPersonal: false,
      );

      final sent = task.toJson()['due_date'] as String;
      expect(sent, endsWith('Z'));
      expect(DateTime.parse(sent).isAtSameMomentAs(dueLocal), isTrue);

      // What Postgres returns for that value.
      final stored =
          '${dueLocal.toUtc().toIso8601String().replaceAll('Z', '')}+00:00';
      final readBack = Task.fromJson({...task.toJson(), 'due_date': stored});
      expect(readBack.dueDate!.isUtc, isFalse);
      expect(readBack.dueDate!.hour, 18);
    });

    test('Task should serialize to JSON correctly', () {
      final now = DateTime.now();
      final task = Task(
        id: '1',
        title: 'Test Task',
        createdById: 'user1',
        status: TaskStatus.unclaimed,
        priority: TaskPriority.normal,
        recurrence: TaskRecurrence.none,
        createdAt: now,
        isPersonal: false,
      );

      final json = task.toJson();

      expect(json['id'], '1');
      expect(json['title'], 'Test Task');
      expect(json['status'], 'unclaimed');
      expect(json['priority'], 'normal');
    });

    test('Task should deserialize from JSON correctly', () {
      final json = {
        'id': '1',
        'title': 'Test Task',
        'description': 'Test Description',
        'created_by_id': 'user1',
        'status': 'unclaimed',
        'priority': 'normal',
        'recurrence': 'none',
        'created_at': DateTime.now().toIso8601String(),
        'is_personal': false,
      };

      final task = Task.fromJson(json);

      expect(task.id, '1');
      expect(task.title, 'Test Task');
      expect(task.status, TaskStatus.unclaimed);
    });

    test('Task should identify urgent priority correctly', () {
      final urgentTask = Task(
        id: '1',
        title: 'Urgent Task',
        createdById: 'user1',
        status: TaskStatus.unclaimed,
        priority: TaskPriority.urgent,
        recurrence: TaskRecurrence.none,
        createdAt: DateTime.now(),
        isPersonal: false,
      );

      expect(urgentTask.isUrgent, true);
    });

    test('Task should identify overdue status correctly', () {
      final overdueTask = Task(
        id: '1',
        title: 'Overdue Task',
        createdById: 'user1',
        status: TaskStatus.unclaimed,
        priority: TaskPriority.normal,
        recurrence: TaskRecurrence.none,
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
        createdAt: DateTime.now(),
        isPersonal: false,
      );

      expect(overdueTask.isOverdue, true);
    });

    test('copyWith(clearCompletedAt: true) clears completedAt', () {
      final task = Task(
        id: '1',
        title: 'Done',
        createdById: 'user1',
        status: TaskStatus.completed,
        priority: TaskPriority.normal,
        recurrence: TaskRecurrence.none,
        createdAt: DateTime.now(),
        completedAt: DateTime.now(),
        isPersonal: false,
      );

      expect(task.copyWith(completedAt: null).completedAt, isNotNull,
          reason: 'a null argument means "keep the existing value"');
      expect(task.copyWith(clearCompletedAt: true).completedAt, isNull);
    });
  });
}

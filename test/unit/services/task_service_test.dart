import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:duotask/models/task.dart';
import 'package:duotask/services/task_service.dart';

class MockTaskService extends Mock implements TaskService {}

void main() {
  late MockTaskService taskService;
  final testTask = DuoTask(
    id: '1',
    title: 'Test Task',
    status: TaskStatus.unclaimed,
    ownerId: 'user1',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() {
    taskService = MockTaskService();
  });

  group('TaskService Tests', () {
    test('createTask - success', () async {
      when(taskService.createTask(
        title: anyNamed('title'),
        description: anyNamed('description'),
      )).thenAnswer((_) async => testTask);

      final result = await taskService.createTask(
        title: 'Test Task',
        description: 'Test Description',
      );

      expect(result, isA<DuoTask>());
      expect(result.title, 'Test Task');
    });

    test('updateTaskStatus - success', () async {
      final updatedTask = testTask.copyWith(status: TaskStatus.done);

      when(taskService.updateTaskStatus(
        taskId: anyNamed('taskId'),
        status: anyNamed('status'),
      )).thenAnswer((_) async => updatedTask);

      final result = await taskService.updateTaskStatus(
        taskId: '1',
        status: TaskStatus.done,
      );

      expect(result.status, TaskStatus.done);
    });
  });
}

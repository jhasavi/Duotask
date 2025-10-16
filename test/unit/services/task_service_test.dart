import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:duotask/models/task.dart';
import 'package:duotask/services/task_service.dart';

class MockTaskService extends Mock implements TaskService {}

void main() {
  late MockTaskService taskService;
  final testTask = Task(
    id: '1',
    title: 'Test Task',
    description: 'Test Description',
    status: TaskStatus.pending,
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

      expect(result, isA<Task>());
      expect(result.title, 'Test Task');
    });

    test('updateTaskStatus - success', () async {
      final updatedTask = testTask.copyWith(status: TaskStatus.completed);
      
      when(taskService.updateTaskStatus(
        taskId: anyNamed('taskId'),
        status: anyNamed('status'),
      )).thenAnswer((_) async => updatedTask);

      final result = await taskService.updateTaskStatus(
        taskId: '1',
        status: TaskStatus.completed,
      );

      expect(result.status, TaskStatus.completed);
    });
  });
}

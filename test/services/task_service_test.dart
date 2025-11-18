import 'package:flutter_test/flutter_test.dart';
import 'package:duotask/services/task_service.dart';
import 'package:duotask/models/task.dart';
import 'package:mockito/mockito.dart';

import '../test_helpers.mocks.dart';

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late TaskService taskService;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();

    when(mockSupabase.auth).thenReturn(mockAuth);
    when(mockAuth.onAuthStateChange).thenAnswer((_) => const Stream.empty());

    taskService = TaskService(mockSupabase);
  });

  group('TaskService Tests', () {
    test('parseNaturalInput should extract time from @6pm', () {
      final result = taskService.parseNaturalInput('Grocery @6pm');
      
      expect(result['title'], 'Grocery');
      expect(result['dueDate'], isNotNull);
      expect(result['priority'], TaskPriority.normal);
    });

    test('parseNaturalInput should detect urgent tasks', () {
      final result = taskService.parseNaturalInput('Urgent: Fix bug');
      
      expect(result['title'], contains('Fix bug'));
      expect(result['priority'], TaskPriority.urgent);
    });

    test('parseNaturalInput should handle tomorrow keyword', () {
      final result = taskService.parseNaturalInput('Call mom tomorrow');
      
      expect(result['title'], contains('Call mom'));
      expect(result['dueDate'], isNotNull);
      final dueDate = result['dueDate'] as DateTime;
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(dueDate.day, tomorrow.day);
    });

    test('parseNaturalInput should handle tonight keyword', () {
      final result = taskService.parseNaturalInput('Clean kitchen tonight');
      
      expect(result['title'], contains('Clean kitchen'));
      expect(result['dueDate'], isNotNull);
      final dueDate = result['dueDate'] as DateTime;
      expect(dueDate.hour, 20);
    });
  });
}

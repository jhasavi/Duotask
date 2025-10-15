import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DuoTask Simple Tests', () {
    test('Basic arithmetic test', () {
      expect(1 + 1, equals(2));
    });

    test('String test', () {
      expect('DuoTask', contains('Task'));
    });

    test('List test', () {
      final tasks = ['Task 1', 'Task 2', 'Task 3'];
      expect(tasks.length, equals(3));
      expect(tasks.first, equals('Task 1'));
    });
  });
}

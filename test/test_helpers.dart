import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:duotask/models/task.dart';
import 'package:duotask/models/user.dart';
import 'package:duotask/models/pairing.dart';

// Generate mocks with build_runner
@GenerateMocks([
  SupabaseClient,
  GoTrueClient,
  PostgrestClient,
  PostgrestQueryBuilder,
  PostgrestFilterBuilder,
  RealtimeClient,
  RealtimeChannel,
])
class TestHelpers {}

/// Test data generators
class TestData {
  static AppUser mockUser({
    String? id,
    String? email,
    String? displayName,
  }) {
    return AppUser(
      id: id ?? 'test-user-123',
      email: email ?? 'test@example.com',
      displayName: displayName ?? 'Test User',
      createdAt: DateTime.now(),
    );
  }

  static AppUser mockPartner({
    String? id,
    String? email,
    String? displayName,
  }) {
    return AppUser(
      id: id ?? 'partner-456',
      email: email ?? 'partner@example.com',
      displayName: displayName ?? 'Partner User',
      createdAt: DateTime.now(),
    );
  }

  static Task mockTask({
    String? id,
    String? title,
    String? createdById,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
    TaskRecurrence? recurrence,
  }) {
    return Task(
      id: id ?? 'task-123',
      title: title ?? 'Test Task',
      createdById: createdById ?? 'test-user-123',
      status: status ?? TaskStatus.unclaimed,
      priority: priority ?? TaskPriority.normal,
      createdAt: DateTime.now(),
      dueDate: dueDate,
      recurrence: recurrence ?? TaskRecurrence.none,
      isPersonal: false,
    );
  }

  static Pairing mockPairing({
    String? id,
    String? requesterId,
    String? recipientId,
    String? pairingCode,
    PairingStatus? status,
  }) {
    return Pairing(
      id: id ?? 'pairing-123',
      requesterId: requesterId ?? 'test-user-123',
      recipientId: recipientId ?? 'partner-456',
      pairingCode: pairingCode ?? 'ABC12345',
      status: status ?? PairingStatus.active,
      createdAt: DateTime.now(),
    );
  }

  static List<Task> mockTaskList({int count = 5}) {
    return List.generate(
      count,
      (index) => mockTask(
        id: 'task-$index',
        title: 'Task $index',
        status: index % 3 == 0
            ? TaskStatus.completed
            : index % 2 == 0
                ? TaskStatus.claimed
                : TaskStatus.unclaimed,
      ),
    );
  }
}

/// Widget test helpers
class WidgetTestHelpers {
  /// Wrap widget with MaterialApp and providers for testing
  static Widget wrapWithMaterialApp(
    Widget child, {
    List<ChangeNotifierProvider>? providers,
  }) {
    if (providers != null) {
      return MultiProvider(
        providers: providers,
        child: MaterialApp(
          home: child,
        ),
      );
    }

    return MaterialApp(
      home: child,
    );
  }

  /// Find text in widget tree (case-insensitive)
  static Finder findTextContaining(String text) {
    return find.byWidgetPredicate(
      (widget) => widget is Text && 
        widget.data?.toLowerCase().contains(text.toLowerCase()) == true,
    );
  }

  /// Wait for async operations to complete
  static Future<void> pumpAndSettle(WidgetTester tester) async {
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }
}

/// Mock response builders
class MockResponses {
  static Map<String, dynamic> userJson({
    String? id,
    String? email,
    String? displayName,
  }) {
    return {
      'id': id ?? 'test-user-123',
      'email': email ?? 'test@example.com',
      'display_name': displayName ?? 'Test User',
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> taskJson({
    String? id,
    String? title,
    String? createdById,
    String? status,
  }) {
    return {
      'id': id ?? 'task-123',
      'title': title ?? 'Test Task',
      'created_by_id': createdById ?? 'test-user-123',
      'status': status ?? 'unclaimed',
      'priority': 'normal',
      'recurrence': 'none',
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> pairingJson({
    String? id,
    String? requesterId,
    String? recipientId,
    String? status,
  }) {
    return {
      'id': id ?? 'pairing-123',
      'requester_id': requesterId ?? 'test-user-123',
      'recipient_id': recipientId ?? 'partner-456',
      'pairing_code': 'ABC12345',
      'status': status ?? 'active',
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}

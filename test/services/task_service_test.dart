import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  group('TaskService undo of completion', () {
    late _FakePostgrest server;
    late SupabaseClient client;
    late TaskService service;

    setUp(() async {
      server = await _FakePostgrest.start();
      client = SupabaseClient(
        server.url,
        'test-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      service = TaskService(client);
    });

    tearDown(() async {
      await client.dispose();
      await server.close();
    });

    Task claimedTask({TaskRecurrence recurrence = TaskRecurrence.none}) {
      return Task(
        id: 'task-1',
        title: 'Water plants',
        createdById: 'user-1',
        claimedById: 'user-1',
        status: TaskStatus.claimed,
        priority: TaskPriority.normal,
        recurrence: recurrence,
        dueDate: DateTime.utc(2026, 10, 14, 9),
        createdAt: DateTime.utc(2026, 10, 1),
        isPersonal: true,
      );
    }

    test('undo deletes the next occurrence created for a recurring task',
        () async {
      final original = claimedTask(recurrence: TaskRecurrence.daily);
      service.tasksForTesting = [original];

      expect(await service.cycleTaskStatus(original, 'user-1'), isTrue);
      expect(service.tasks.single.status, TaskStatus.completed);
      expect(service.tasks.single.completedAt, isNotNull);

      final inserted = server.requests
          .where((r) => r.method == 'POST' && r.path == '/rest/v1/tasks');
      expect(inserted, hasLength(1),
          reason: 'completing a daily task should create the next one');
      final spawnedId = server.insertedIds.single;

      // The Undo snackbar holds the pre-completion snapshot.
      expect(await service.revertCompletion(original), isTrue);

      final deletes = server.requests.where((r) => r.method == 'DELETE');
      expect(deletes, hasLength(1));
      expect(deletes.single.query['id'], 'eq.$spawnedId');

      final reverted = service.tasks.singleWhere((t) => t.id == original.id);
      expect(reverted.status, TaskStatus.claimed);
      expect(reverted.completedAt, isNull);
      expect(service.tasks.where((t) => t.id == spawnedId), isEmpty);

      final patch = server.requests.singleWhere((r) => r.method == 'PATCH');
      expect(patch.query['id'], 'eq.${original.id}');
      expect(patch.body['status'], 'claimed');
      expect(patch.body.containsKey('completed_at'), isTrue);
      expect(patch.body['completed_at'], isNull);
    });

    test('undo of a non-recurring task does not delete anything', () async {
      final original = claimedTask();
      service.tasksForTesting = [original];

      expect(await service.cycleTaskStatus(original, 'user-1'), isTrue);
      expect(await service.revertCompletion(original), isTrue);

      expect(server.requests.where((r) => r.method == 'DELETE'), isEmpty);
      expect(
          server.requests
              .where((r) => r.method == 'POST' && r.path == '/rest/v1/tasks'),
          isEmpty);
      final reverted = service.tasks.single;
      expect(reverted.status, TaskStatus.claimed);
      expect(reverted.completedAt, isNull);
    });

    test('revertCompletion is a no-op when the task is not completed',
        () async {
      final original = claimedTask();
      service.tasksForTesting = [original];

      expect(await service.revertCompletion(original), isFalse);
      expect(server.requests, isEmpty);
    });
  });
}

class _RecordedRequest {
  _RecordedRequest(this.method, this.path, this.query, this.body);

  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, dynamic> body;
}

/// A minimal in-process stand-in for PostgREST, so the real Supabase client
/// (and the query it builds) is exercised without any network or live DB.
class _FakePostgrest {
  _FakePostgrest._(this._server);

  final HttpServer _server;
  final requests = <_RecordedRequest>[];
  final insertedIds = <String>[];

  String get url => 'http://${_server.address.host}:${_server.port}';

  static Future<_FakePostgrest> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakePostgrest._(server);
    server.listen(fake._handle);
    return fake;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    final decoded = raw.isEmpty ? null : jsonDecode(raw);
    final body =
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    requests.add(_RecordedRequest(
      request.method,
      request.uri.path,
      request.uri.queryParameters,
      body,
    ));

    final response = request.response..headers.contentType = ContentType.json;
    final now = DateTime.now().toUtc().toIso8601String();

    if (request.uri.path == '/rest/v1/rpc/cycle_task_status') {
      response.write(jsonEncode({
        'id': body['task_uuid'],
        'status': 'completed',
        'claimed_by_id': body['user_uuid'],
        'claimed_at': now,
        'completed_at': now,
        'updated_at': now,
      }));
    } else if (request.method == 'POST' &&
        request.uri.path == '/rest/v1/tasks') {
      insertedIds.add(body['id'] as String);
      response.write(jsonEncode(body));
    } else {
      response.statusCode = HttpStatus.noContent;
    }
    await response.close();
  }
}

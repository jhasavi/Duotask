import 'package:duotask/models/task_share.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> shareJson([Map<String, dynamic> overrides = const {}]) => {
      'id': 's1',
      'token': 'abcdefghijklmnopqrstuvwx',
      'task_id': 't1',
      'created_by_id': 'u1',
      'recipient_name': 'Priya',
      'response': 'pending',
      'responded_at': null,
      'first_opened_at': null,
      'open_count': 0,
      'claimed_by_id': null,
      'expires_at': '2026-11-15T12:00:00Z',
      'revoked_at': null,
      'created_at': '2026-10-16T12:00:00Z',
      ...overrides,
    };

void main() {
  final now = DateTime.utc(2026, 10, 20);

  group('TaskShare.fromJson', () {
    test('parses a row from task_shares', () {
      final share = TaskShare.fromJson(shareJson({
        'response': 'accepted',
        'first_opened_at': '2026-10-16T13:00:00Z',
        'open_count': 3,
      }));
      expect(share.token, 'abcdefghijklmnopqrstuvwx');
      expect(share.response, ShareResponse.accepted);
      expect(share.openCount, 3);
      expect(
        share.firstOpenedAt!.isAtSameMomentAs(DateTime.utc(2026, 10, 16, 13)),
        isTrue,
      );
      expect(share.isLive(now), isTrue);
      expect(share.hasActivity, isTrue);
    });

    test('treats an unknown response as pending', () {
      final share = TaskShare.fromJson(shareJson({'response': 'weird'}));
      expect(share.response, ShareResponse.pending);
      expect(share.hasActivity, isFalse);
    });
  });

  group('statusLine', () {
    String line(Map<String, dynamic> o) =>
        TaskShare.fromJson(shareJson(o)).statusLine(now);

    test('names the recipient for each response', () {
      expect(line({}), 'Link ready, not opened yet');
      expect(line({'first_opened_at': '2026-10-17T00:00:00Z'}),
          'Priya opened the link');
      expect(line({'response': 'accepted'}), "Priya said they'll do it");
      expect(line({'response': 'declined'}), "Priya can't do it");
      expect(line({'response': 'done'}), 'Priya marked it done');
      expect(line({'claimed_by_id': 'u2'}), 'Priya joined DuoTask');
    });

    test('falls back when there is no name', () {
      expect(line({'recipient_name': null, 'response': 'done'}),
          'Your contact marked it done');
    });

    test('reports expired and turned-off links', () {
      expect(line({'expires_at': '2026-10-19T00:00:00Z'}), 'Link expired');
      expect(line({'revoked_at': '2026-10-18T00:00:00Z'}), 'Link turned off');
    });
  });

  group('buildUrl', () {
    test('appends /t/<token> with or without a trailing slash', () {
      expect(TaskShare.buildUrl('https://duotask.app', 'tok').toString(),
          'https://duotask.app/t/tok');
      expect(TaskShare.buildUrl('https://duotask.app/', 'tok').toString(),
          'https://duotask.app/t/tok');
    });
  });

  group('buildMessage', () {
    final url = Uri.parse('https://duotask.app/t/tok');

    test('greets by name and includes the title and link', () {
      final msg = TaskShare.buildMessage(
          taskTitle: 'Pick up dry cleaning', url: url, recipientName: 'Sam');
      expect(msg, startsWith('Hi Sam! '));
      expect(msg, contains('"Pick up dry cleaning"'));
      expect(msg, contains('no app needed'));
      expect(msg, endsWith('https://duotask.app/t/tok'));
    });

    test('omits the greeting when there is no name, and shows the due date',
        () {
      final msg = TaskShare.buildMessage(
        taskTitle: 'Groceries',
        url: url,
        recipientName: '  ',
        dueDate: DateTime(2026, 10, 23, 18),
      );
      expect(msg, startsWith('Could you'));
      expect(msg, contains('(due Fri Oct 23, 6:00 PM)'));
    });
  });

  test('isValidToken accepts URL-safe base64 only', () {
    expect(TaskShare.isValidToken('abcdefghijklmnopqrstuvwx'), isTrue);
    expect(TaskShare.isValidToken('ab-_CDEFGHIJKLMNOPQRSTUV'), isTrue);
    expect(TaskShare.isValidToken('short'), isFalse);
    expect(TaskShare.isValidToken("abc'; drop table x;--xxxxxx"), isFalse);
    expect(TaskShare.isValidToken(null), isFalse);
  });
}

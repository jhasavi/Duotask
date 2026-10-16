import 'package:duotask/models/task.dart';
import 'package:duotask/services/task_share_service.dart';
import 'package:duotask/widgets/send_task_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../unit/services/task_share_service_test.dart' show FakeTaskShareApi;

Task task({
  String createdById = 'u1',
  TaskVisibility visibility = TaskVisibility.personal,
  TaskRecurrence recurrence = TaskRecurrence.none,
  TaskStatus status = TaskStatus.unclaimed,
}) =>
    Task(
      id: 't1',
      title: 'Pick up dry cleaning',
      createdById: createdById,
      status: status,
      priority: TaskPriority.normal,
      recurrence: recurrence,
      createdAt: DateTime(2026, 10, 16),
      visibility: visibility,
    );

void main() {
  group('canSendByLink', () {
    test('allows the owner\'s open, personal, one-off tasks', () {
      expect(canSendByLink(task(), 'u1'), isTrue);
    });

    test('matches the checks in create_task_share', () {
      expect(canSendByLink(task(), null), isFalse);
      expect(canSendByLink(task(createdById: 'u2'), 'u1'), isFalse);
      expect(canSendByLink(task(visibility: TaskVisibility.group), 'u1'),
          isFalse);
      expect(canSendByLink(task(recurrence: TaskRecurrence.weekly), 'u1'),
          isFalse);
      expect(canSendByLink(task(status: TaskStatus.completed), 'u1'), isFalse);
    });
  });

  group('sendUri', () {
    const msg = 'Hi Sam! "Milk & eggs" https://duotask.app/t/tok';

    test('encodes the message for each channel', () {
      final wa = sendUri(SendChannel.whatsApp, msg)!;
      expect(wa.host, 'wa.me');
      expect(Uri.decodeComponent(wa.toString().split('text=')[1]), msg);

      final sms = sendUri(SendChannel.text, msg)!;
      expect(sms.scheme, 'sms');
      expect(Uri.decodeComponent(sms.toString().split('body=')[1]), msg);

      final mail = sendUri(SendChannel.email, msg, subject: 'Milk & eggs')!;
      expect(mail.scheme, 'mailto');
      expect(mail.toString(), contains('subject=Milk%20%26%20eggs'));

      expect(sendUri(SendChannel.copy, msg), isNull);
    });
  });

  group('SendTaskSheet', () {
    late FakeTaskShareApi api;
    late TaskShareService service;
    late List<Uri> launched;
    String? clipboard;

    setUp(() {
      api = FakeTaskShareApi();
      service = TaskShareService(api, appBaseUrl: 'https://duotask.app');
      launched = [];
      clipboard = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
    });

    Future<void> pumpSheet(WidgetTester tester, {bool launchOk = true}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider.value(
            value: service,
            child: SendTaskSheet(
              task: task(),
              launcher: (uri) async {
                launched.add(uri);
                return launchOk;
              },
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('creates the link as soon as it opens', (tester) async {
      await pumpSheet(tester);
      expect(api.created, [('t1', null)]);
      expect(service.shareFor('t1'), isNotNull);
    });

    testWidgets('WhatsApp opens a message with the name, title and link, '
        'then saves the name', (tester) async {
      await pumpSheet(tester);
      await tester.enterText(find.byKey(const Key('send_task_name')), 'Sam');
      await tester.tap(find.text('WhatsApp'));
      await tester.pumpAndSettle();

      expect(launched, hasLength(1));
      final text = Uri.decodeComponent(launched.single.toString());
      expect(text, contains('Hi Sam!'));
      expect(text, contains('Pick up dry cleaning'));
      expect(text, contains('https://duotask.app/t/abcdefghijklmnopqrstuvwx'));
      expect(api.created.last, ('t1', 'Sam'));
    });

    testWidgets('Copy link puts the whole message on the clipboard',
        (tester) async {
      await pumpSheet(tester);
      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();

      expect(launched, isEmpty);
      expect(clipboard, contains('/t/abcdefghijklmnopqrstuvwx'));
      expect(find.textContaining('copied'), findsOneWidget);
    });

    testWidgets('falls back to copying when the app can\'t be opened',
        (tester) async {
      await pumpSheet(tester, launchOk: false);
      await tester.tap(find.text('Text'));
      await tester.pumpAndSettle();

      expect(clipboard, isNotNull);
      expect(find.textContaining("Couldn't open that app"), findsOneWidget);
    });

    testWidgets('shows the message for copying by hand when the clipboard '
        'is blocked, and still saves the name', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'denied');
        }
        return null;
      });
      await pumpSheet(tester);
      await tester.enterText(find.byKey(const Key('send_task_name')), 'Mom');
      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();

      expect(find.textContaining("Copying isn't allowed"), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(api.created.last, ('t1', 'Mom'));
    });

    testWidgets('shows why a link can\'t be made', (tester) async {
      api.createError = Exception('offline');
      await pumpSheet(tester);
      expect(find.textContaining('Check your connection'), findsOneWidget);
      final whatsApp = tester.widget<FilledButton>(find.ancestor(
          of: find.text('WhatsApp'), matching: find.byType(FilledButton)));
      expect(whatsApp.onPressed, isNull);
    });
  });
}

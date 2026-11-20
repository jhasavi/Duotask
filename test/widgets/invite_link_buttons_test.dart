import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evenhalf/widgets/invite_link_buttons.dart';

void main() {
  late List<Uri> launched;
  late List<String> sent;
  late bool launchSucceeds;

  Widget host() => MaterialApp(
        home: Scaffold(
          body: InviteLinkButtons(
            code: 'AB12CD34',
            appBaseUrl: 'https://evenhalf.example.com',
            onSent: sent.add,
            launcher: (uri) async {
              launched.add(uri);
              return launchSucceeds;
            },
          ),
        ),
      );

  String? copied;

  setUp(() {
    launched = [];
    sent = [];
    launchSucceeds = true;
    copied = null;
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
  });

  tearDown(() => TestWidgetsFlutterBinding.ensureInitialized()
      .defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));

  testWidgets('WhatsApp opens with the invite link and logs the channel',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('invite_whatsapp')));
    await tester.pumpAndSettle();

    expect(launched, hasLength(1));
    expect(launched.single.host, 'wa.me');
    final text = launched.single.queryParameters['text']!;
    expect(text, contains('https://evenhalf.example.com/?pair=AB12CD34'));
    expect(sent, ['whatsapp']);
  });

  testWidgets('Copy link copies the message', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('invite_copy')));
    await tester.pumpAndSettle();

    expect(launched, isEmpty);
    expect(copied, contains('?pair=AB12CD34'));
    expect(find.byKey(const Key('invite_notice')), findsOneWidget);
    expect(sent, ['copy']);
  });

  testWidgets("falls back to copying when the app can't be opened",
      (tester) async {
    launchSucceeds = false;
    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('invite_text')));
    await tester.pumpAndSettle();

    expect(launched.single.scheme, 'sms');
    expect(copied, contains('?pair=AB12CD34'));
    expect(find.textContaining("Couldn't open that app"), findsOneWidget);
    expect(sent, ['text']);
  });
}

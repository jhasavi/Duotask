import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duotask/widgets/timezone_picker.dart';

class _Harness extends StatelessWidget {
  final String current;
  final void Function(String?) onResult;

  const _Harness({required this.current, required this.onResult});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                onResult(await showTimezonePicker(context, current: current));
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('searching and tapping a zone returns its IANA name',
      (tester) async {
    String? result;
    await tester.pumpWidget(
      _Harness(current: 'UTC', onResult: (v) => result = v),
    );
    await _open(tester);

    await tester.enterText(find.byKey(const Key('tz-search')), 'kolkata');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tz-Asia/Kolkata')), findsOneWidget);
    expect(find.byKey(const Key('tz-America/New_York')), findsNothing);

    await tester.tap(find.byKey(const Key('tz-Asia/Kolkata')));
    await tester.pumpAndSettle();

    expect(result, 'Asia/Kolkata');
  });

  testWidgets('marks the current zone with a check', (tester) async {
    await tester.pumpWidget(
      _Harness(current: 'Africa/Abidjan', onResult: (_) {}),
    );
    await _open(tester);

    expect(find.byIcon(Icons.check), findsOneWidget);
    final tile = tester.widget<ListTile>(
      find.byKey(const Key('tz-Africa/Abidjan')),
    );
    expect(tile.selected, isTrue);
  });

  testWidgets('shows an empty state when nothing matches', (tester) async {
    await tester.pumpWidget(_Harness(current: 'UTC', onResult: (_) {}));
    await _open(tester);

    await tester.enterText(find.byKey(const Key('tz-search')), 'zzzz-nope');
    await tester.pumpAndSettle();

    expect(find.text('No matching timezones'), findsOneWidget);
  });

  testWidgets('dismissing without choosing returns null', (tester) async {
    String? result = 'sentinel';
    await tester.pumpWidget(
      _Harness(current: 'UTC', onResult: (v) => result = v),
    );
    await _open(tester);

    // Tap the modal barrier above the sheet.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}

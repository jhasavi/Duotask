import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:duotask/models/premium_status.dart';
import 'package:duotask/screens/stats_screen.dart';
import 'package:duotask/services/premium_service.dart';
import 'package:duotask/utils/pair_stats.dart';

void main() {
  Widget host(PremiumService premium) => ChangeNotifierProvider.value(
        value: premium,
        child: const MaterialApp(home: StatsScreen()),
      );

  testWidgets('free users see the paywall with an upgrade button',
      (tester) async {
    final premium = PremiumService(
      () async => PremiumStatus.free,
      paymentLinkUrl: 'https://buy.stripe.com/test',
    );

    await tester.pumpWidget(host(premium));
    await tester.pumpAndSettle();

    expect(find.text('Streaks & partner stats'), findsOneWidget);
    expect(find.byKey(const Key('upgrade_button')), findsOneWidget);
    expect(find.text('Already upgraded? Refresh'), findsOneWidget);
  });

  testWidgets('without a payment link the paywall says coming soon',
      (tester) async {
    final premium = PremiumService(
      () async => PremiumStatus.free,
      paymentLinkUrl: '',
    );

    await tester.pumpWidget(host(premium));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('upgrade_button')), findsNothing);
    expect(find.text('Premium is coming soon.'), findsOneWidget);
  });

  testWidgets('PairStatsView shows streaks and the partner split',
      (tester) async {
    final now = DateTime.now();
    final stats = PairStats.compute(
      [
        Completion(completedById: 'me', completedAt: now),
        Completion(
          completedById: 'p',
          completedAt: DateTime(now.year, now.month, now.day - 1, 12),
        ),
        Completion(completedById: 'me', completedAt: now),
      ],
      myId: 'me',
      partnerId: 'p',
      now: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PairStatsView(stats: stats, partnerName: 'Sam'),
        ),
      ),
    );

    expect(find.text('2'), findsWidgets); // current and best streak
    expect(find.text('You: 2'), findsOneWidget);
    expect(find.text('Sam: 1'), findsOneWidget);
    expect(find.textContaining('67%'), findsOneWidget);
    expect(find.textContaining('Streak safe'), findsOneWidget);
  });
}

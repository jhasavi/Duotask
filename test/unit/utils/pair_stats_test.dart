import 'package:flutter_test/flutter_test.dart';

import 'package:duotask/utils/pair_stats.dart';

void main() {
  const me = 'me';
  const partner = 'partner';
  // A Wednesday afternoon, local time.
  final now = DateTime(2026, 10, 14, 15, 30);

  Completion done(String by, int daysAgo, {int hour = 12}) => Completion(
        completedById: by,
        completedAt: DateTime(now.year, now.month, now.day - daysAgo, hour),
      );

  PairStats stats(List<Completion> completions, {String? partnerId}) =>
      PairStats.compute(
        completions,
        myId: me,
        partnerId: partnerId ?? partner,
        now: now,
      );

  group('streaks', () {
    test('no completions means no streak', () {
      final s = stats([]);
      expect(s.currentStreak, 0);
      expect(s.bestStreak, 0);
      expect(s.completedToday, false);
    });

    test('consecutive days ending today count, by either partner', () {
      final s = stats([done(me, 0), done(partner, 1), done(me, 2)]);
      expect(s.currentStreak, 3);
      expect(s.completedToday, true);
    });

    test('a streak ending yesterday is still alive today', () {
      final s = stats([done(me, 1), done(partner, 2)]);
      expect(s.currentStreak, 2);
      expect(s.completedToday, false);
    });

    test('a gap of a full day breaks the streak', () {
      final s = stats([done(me, 2), done(me, 3)]);
      expect(s.currentStreak, 0);
      expect(s.bestStreak, 2);
    });

    test('several completions on one day count once', () {
      final s = stats([
        done(me, 0, hour: 8),
        done(partner, 0, hour: 20),
        done(me, 1),
      ]);
      expect(s.currentStreak, 2);
    });

    test('best streak finds the longest past run', () {
      final s = stats([
        done(me, 0),
        for (var d = 10; d < 15; d++) done(partner, d),
      ]);
      expect(s.currentStreak, 1);
      expect(s.bestStreak, 5);
    });

    test('streaks span month boundaries', () {
      final s = PairStats.compute(
        [
          Completion(completedById: me, completedAt: DateTime(2026, 10, 1)),
          Completion(completedById: me, completedAt: DateTime(2026, 9, 30)),
          Completion(completedById: me, completedAt: DateTime(2026, 9, 29)),
        ],
        myId: me,
        now: DateTime(2026, 10, 1, 9),
      );
      expect(s.currentStreak, 3);
    });

    test('future-dated completions (clock skew) are ignored', () {
      final s = stats([done(me, -1)]);
      expect(s.currentStreak, 0);
      expect(s.bestStreak, 0);
    });
  });

  group('partner split', () {
    test('counts each person within the 30-day window', () {
      final s = stats([
        done(me, 0),
        done(me, 5),
        done(partner, 29),
        done(partner, 30), // outside the window
      ]);
      expect(s.myCount, 2);
      expect(s.partnerCount, 1);
      expect(s.totalCount, 3);
      expect(s.myShare, closeTo(2 / 3, 1e-9));
    });

    test('share is null with nothing completed', () {
      expect(stats([]).myShare, isNull);
    });

    test('completions by anyone else are not attributed to the partner', () {
      final s = stats([done('ex-partner', 1)], partnerId: partner);
      expect(s.partnerCount, 0);
      expect(s.myCount, 0);
    });

    test('unpaired users only see their own count', () {
      final s = PairStats.compute(
        [done(me, 0), done(partner, 0)],
        myId: me,
        now: now,
      );
      expect(s.myCount, 1);
      expect(s.partnerCount, 0);
    });
  });

  group('last 7 days', () {
    test('buckets oldest first with today last', () {
      final s = stats([done(me, 0), done(me, 0), done(partner, 6)]);
      expect(s.last7Days, [1, 0, 0, 0, 0, 0, 2]);
    });

    test('ignores anything older than a week', () {
      expect(stats([done(me, 7)]).last7Days, everyElement(0));
    });
  });

  group('Completion.fromTaskRow', () {
    test('prefers the claimer, falls back to the creator', () {
      final claimed = Completion.fromTaskRow({
        'claimed_by_id': 'b',
        'created_by_id': 'a',
        'completed_at': '2026-10-14T12:00:00Z',
      });
      expect(claimed!.completedById, 'b');

      final unclaimed = Completion.fromTaskRow({
        'claimed_by_id': null,
        'created_by_id': 'a',
        'completed_at': '2026-10-14T12:00:00Z',
      });
      expect(unclaimed!.completedById, 'a');
    });

    test('skips rows without a usable completion time', () {
      expect(
        Completion.fromTaskRow({'created_by_id': 'a', 'completed_at': null}),
        isNull,
      );
      expect(
        Completion.fromTaskRow({'created_by_id': 'a', 'completed_at': 'nope'}),
        isNull,
      );
    });
  });
}

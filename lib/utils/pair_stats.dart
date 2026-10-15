/// Completion streaks and partner stats (a Premium feature).
///
/// Pure functions over completion records so they can be unit tested
/// without a backend; [StatsService] supplies the records.
library;

/// One completed task: who completed it and when.
class Completion {
  final String completedById;
  final DateTime completedAt;

  const Completion({required this.completedById, required this.completedAt});

  /// Builds a completion from a `tasks` row. The completer is whoever had
  /// claimed the task, falling back to its creator for tasks completed
  /// straight from unclaimed.
  static Completion? fromTaskRow(Map<String, dynamic> row) {
    final completedAt = row['completed_at'];
    final by = (row['claimed_by_id'] ?? row['created_by_id']) as String?;
    if (completedAt is! String || by == null) return null;
    final at = DateTime.tryParse(completedAt);
    if (at == null) return null;
    return Completion(completedById: by, completedAt: at);
  }
}

class PairStats {
  /// Consecutive days, ending today, on which the pair completed at least
  /// one task. A streak survives until the end of the day after its last
  /// completion, so it isn't shown as broken first thing in the morning.
  final int currentStreak;
  final int bestStreak;
  final bool completedToday;

  /// Completions in the last [windowDays] days, today included.
  final int myCount;
  final int partnerCount;
  final int windowDays;

  /// Completions per day for the last 7 days, oldest first, today last.
  final List<int> last7Days;

  const PairStats({
    required this.currentStreak,
    required this.bestStreak,
    required this.completedToday,
    required this.myCount,
    required this.partnerCount,
    required this.windowDays,
    required this.last7Days,
  });

  int get totalCount => myCount + partnerCount;

  /// The current user's share of the pair's completions, 0–1, or null when
  /// there are none to split.
  double? get myShare => totalCount == 0 ? null : myCount / totalCount;

  static PairStats compute(
    Iterable<Completion> completions, {
    required String myId,
    String? partnerId,
    required DateTime now,
    int windowDays = 30,
  }) {
    final today = _day(now);
    final windowStart = _addDays(today, -(windowDays - 1));
    final weekStart = _addDays(today, -6);

    final days = <DateTime>{};
    final last7 = List<int>.filled(7, 0);
    var mine = 0;
    var theirs = 0;

    for (final c in completions) {
      final day = _day(c.completedAt.toLocal());
      if (day.isAfter(today)) continue; // clock skew; ignore the future
      days.add(day);

      if (!day.isBefore(windowStart)) {
        if (c.completedById == myId) {
          mine++;
        } else if (partnerId != null && c.completedById == partnerId) {
          theirs++;
        }
      }
      if (!day.isBefore(weekStart)) {
        last7[_daysBetween(weekStart, day)]++;
      }
    }

    return PairStats(
      currentStreak: _currentStreak(days, today),
      bestStreak: _bestStreak(days),
      completedToday: days.contains(today),
      myCount: mine,
      partnerCount: theirs,
      windowDays: windowDays,
      last7Days: last7,
    );
  }

  static int _currentStreak(Set<DateTime> days, DateTime today) {
    var cursor = days.contains(today) ? today : _addDays(today, -1);
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = _addDays(cursor, -1);
    }
    return streak;
  }

  static int _bestStreak(Set<DateTime> days) {
    if (days.isEmpty) return 0;
    final sorted = days.toList()..sort();
    var best = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      run = _addDays(sorted[i - 1], 1) == sorted[i] ? run + 1 : 1;
      if (run > best) best = run;
    }
    return best;
  }

  // Calendar-day arithmetic via the DateTime constructor, which normalises
  // overflow and is unaffected by DST (Duration(days: 1) is not).
  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  static DateTime _addDays(DateTime day, int n) =>
      DateTime(day.year, day.month, day.day + n);

  static int _daysBetween(DateTime from, DateTime to) {
    var n = 0;
    var cursor = from;
    while (cursor.isBefore(to)) {
      cursor = _addDays(cursor, 1);
      n++;
    }
    return n;
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/pair_stats.dart';

/// Loads completion history for the streaks and partner stats screen.
///
/// Reads `tasks` directly; row-level security already limits the result to
/// the caller's own tasks and their pair's shared ones, which is exactly the
/// set the stats should cover.
class StatsService {
  final SupabaseClient _supabase;

  StatsService(this._supabase);

  /// A year of history is enough for "best streak" to be meaningful while
  /// keeping the query small.
  static const lookbackDays = 365;

  Future<List<Completion>> loadCompletions({DateTime? now}) async {
    final since = (now ?? DateTime.now()).subtract(
      const Duration(days: lookbackDays),
    );
    final rows = await _supabase
        .from('tasks')
        .select('claimed_by_id, created_by_id, completed_at')
        .eq('status', 'completed')
        .gte('completed_at', since.toUtc().toIso8601String())
        .order('completed_at');

    return [
      for (final row in rows)
        if (Completion.fromTaskRow(row) case final completion?) completion,
    ];
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/theme.dart';
import '../services/auth_service.dart';
import '../services/pairing_service.dart';
import '../services/premium_service.dart';
import '../services/stats_service.dart';
import '../utils/pair_stats.dart';
import '../widgets/premium_widgets.dart';

/// Completion streaks and partner stats — the first DuoTask Premium feature.
/// Free users see what it offers and an upgrade button instead.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Future<PairStats>? _stats;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final premium = context.read<PremiumService>();
    await premium.refresh();
    if (!mounted) return;
    setState(() {
      _stats = premium.isPremium ? _loadStats() : null;
    });
  }

  Future<PairStats> _loadStats() async {
    final myId = context.read<AuthService>().currentUser!.id;
    final partnerId = context.read<PairingService>().partner?.id;
    final completions =
        await StatsService(context.read<SupabaseClient>()).loadCompletions();
    return PairStats.compute(
      completions,
      myId: myId,
      partnerId: partnerId,
      now: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Streaks & Stats')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: !premium.hasLoaded && premium.isLoading
            ? const Center(child: CircularProgressIndicator())
            : premium.isPremium
                ? _StatsView(stats: _stats)
                : _Paywall(onRefresh: _refresh),
      ),
    );
  }
}

class _StatsView extends StatelessWidget {
  final Future<PairStats>? stats;

  const _StatsView({required this.stats});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PairStats>(
      future: stats,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            children: const [
              SizedBox(height: 120),
              Center(child: Text('Could not load your stats. Pull to retry.')),
            ],
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final partnerName =
            context.watch<PairingService>().partner?.displayName ?? 'Partner';
        return PairStatsView(stats: snapshot.data!, partnerName: partnerName);
      },
    );
  }
}

/// The stats layout itself, separated from loading so it can be tested.
class PairStatsView extends StatelessWidget {
  final PairStats stats;
  final String partnerName;

  const PairStatsView({
    super.key,
    required this.stats,
    required this.partnerName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = stats.myShare;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.local_fire_department,
                color: AppTheme.unclaimedPartnerColor,
                value: '${stats.currentStreak}',
                label: 'day streak',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.emoji_events,
                color: AppTheme.accentColor,
                value: '${stats.bestStreak}',
                label: 'best streak',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          stats.completedToday
              ? 'You two have finished something today. Streak safe!'
              : stats.currentStreak > 0
                  ? 'Finish one task today to keep the streak going.'
                  : 'Finish a task today to start a streak.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Text('Last 7 days', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _WeekBars(counts: stats.last7Days),
        const SizedBox(height: 24),
        Text(
          'Last ${stats.windowDays} days',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('You: ${stats.myCount}'),
            Text('$partnerName: ${stats.partnerCount}'),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: share ?? 0,
            minHeight: 12,
            color: AppTheme.primaryColor,
            backgroundColor: share == null
                ? theme.colorScheme.surfaceContainerHighest
                : AppTheme.secondaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          share == null
              ? 'No completed tasks yet.'
              : 'You did ${(share * 100).round()}% of the '
                  '${stats.totalCount} tasks you two finished.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  final List<int> counts;

  const _WeekBars({required this.counts});

  @override
  Widget build(BuildContext context) {
    final max = counts.fold<int>(1, (m, c) => c > m ? c : m);
    final today = DateTime.now();
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < counts.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${counts[i]}', style: const TextStyle(fontSize: 11)),
                  const SizedBox(height: 2),
                  Container(
                    height: 70 * counts[i] / max + 2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: counts[i] > 0
                          ? AppTheme.completedColor
                          : AppTheme.textTertiary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    names[DateTime(
                          today.year,
                          today.month,
                          today.day - (counts.length - 1 - i),
                        ).weekday -
                        1],
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Paywall extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _Paywall({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final premium = context.watch<PremiumService>();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(
          Icons.local_fire_department,
          size: 64,
          color: AppTheme.unclaimedPartnerColor,
        ),
        const SizedBox(height: 16),
        Text(
          'Streaks & partner stats',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Part of DuoTask Premium. One subscription covers both of you.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const ListTile(
          leading: Icon(Icons.local_fire_department),
          title: Text('Daily streaks'),
          subtitle: Text('See how many days in a row you two get things done'),
        ),
        const ListTile(
          leading: Icon(Icons.bar_chart),
          title: Text('Your week at a glance'),
          subtitle: Text('Tasks finished each day'),
        ),
        const ListTile(
          leading: Icon(Icons.people),
          title: Text('Who did what'),
          subtitle: Text('A friendly split of the last 30 days'),
        ),
        const SizedBox(height: 24),
        if (premium.canUpgrade)
          FilledButton.icon(
            key: const Key('upgrade_button'),
            onPressed: () => openPremiumCheckout(context),
            icon: const Icon(Icons.workspace_premium),
            label: const Text('Upgrade to Premium'),
          )
        else
          Text(
            'Premium is coming soon.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: premium.isLoading ? null : onRefresh,
          child: const Text('Already upgraded? Refresh'),
        ),
      ],
    );
  }
}

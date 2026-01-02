import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';

/// Weekly summary modal shown once per week on Sunday
class WeeklySummaryModal extends StatelessWidget {
  final String userName;
  final String partnerName;
  final int userCompletedCount;
  final int partnerCompletedCount;

  const WeeklySummaryModal({
    super.key,
    required this.userName,
    required this.partnerName,
    required this.userCompletedCount,
    required this.partnerCompletedCount,
  });

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShownWeek = prefs.getString('weekly_summary_last_shown');
    final currentWeek = _getCurrentWeekKey();
    
    return lastShownWeek != currentWeek;
  }

  static Future<void> markAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    final currentWeek = _getCurrentWeekKey();
    await prefs.setString('weekly_summary_last_shown', currentWeek);
  }

  static String _getCurrentWeekKey() {
    final now = DateTime.now();
    // Get the Sunday of current week
    final sunday = now.subtract(Duration(days: now.weekday % 7));
    return '${sunday.year}-W${sunday.month.toString().padLeft(2, '0')}-${sunday.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final totalCompleted = userCompletedCount + partnerCompletedCount;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Celebration icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.celebration,
                size: 48,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'This Week',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),

            // Stats
            _buildStatRow(
              context,
              userName,
              userCompletedCount,
              Colors.blue,
            ),
            const SizedBox(height: 16),
            _buildStatRow(
              context,
              partnerName,
              partnerCompletedCount,
              Colors.purple,
            ),
            
            const SizedBox(height: 24),
            
            // Divider
            Container(
              height: 1,
              color: AppTheme.textSecondary.withOpacity(0.2),
            ),
            
            const SizedBox(height: 24),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$totalCompleted',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.completedColor,
                      ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    'shared tasks\nfinished together 🎉',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.3,
                        ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Close button
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text('Great!'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String name,
    int count,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                'completed $count shared ${count == 1 ? 'task' : 'tasks'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

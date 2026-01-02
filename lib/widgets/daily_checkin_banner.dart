import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/pairing_service.dart';
import '../config/theme.dart';

/// Daily check-in banner showing today's shared tasks
/// Only shown when user is paired
class DailyCheckInBanner extends StatefulWidget {
  final VoidCallback? onFocusMode;

  const DailyCheckInBanner({
    super.key,
    this.onFocusMode,
  });

  @override
  State<DailyCheckInBanner> createState() => _DailyCheckInBannerState();
}

class _DailyCheckInBannerState extends State<DailyCheckInBanner> {
  bool _isHidden = false;

  @override
  void initState() {
    super.initState();
    _checkIfHiddenToday();
  }

  Future<void> _checkIfHiddenToday() async {
    final prefs = await SharedPreferences.getInstance();
    final hiddenDate = prefs.getString('daily_banner_hidden_date');
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    if (hiddenDate == today) {
      setState(() => _isHidden = true);
    } else {
      // Reset if it's a new day
      if (hiddenDate != null && hiddenDate != today) {
        await prefs.remove('daily_banner_hidden_date');
      }
    }
  }

  Future<void> _hideForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    await prefs.setString('daily_banner_hidden_date', today);
    setState(() => _isHidden = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isHidden) return const SizedBox.shrink();

    return Consumer2<PairingService, TaskService>(
      builder: (context, pairingService, taskService, child) {
        // Only show when paired
        if (!pairingService.isPaired) {
          return const SizedBox.shrink();
        }

        // Get group tasks
        final groupTasks = taskService.tasks
            .where((t) => t.visibility == TaskVisibility.group)
            .toList();

        final unclaimedCount = groupTasks
            .where((t) => t.status == TaskStatus.unclaimed)
            .length;

        final claimedCount = groupTasks
            .where((t) => t.status == TaskStatus.claimed)
            .length;

        // Get top 3 most urgent/nearest-due tasks
        final activeTasks = groupTasks
            .where((t) => 
              t.status == TaskStatus.unclaimed || 
              t.status == TaskStatus.claimed
            )
            .toList();

        // Sort by priority (urgent first) then by due date
        activeTasks.sort((a, b) {
          if (a.priority != b.priority) {
            return a.priority == TaskPriority.urgent ? -1 : 1;
          }
          if (a.dueDate != null && b.dueDate != null) {
            return a.dueDate!.compareTo(b.dueDate!);
          }
          if (a.dueDate != null) return -1;
          if (b.dueDate != null) return 1;
          return 0;
        });

        final topTasks = activeTasks.take(3).toList();

        // Don't show if no active group tasks
        if (activeTasks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withOpacity(0.1),
                AppTheme.primaryColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.today,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Today\'s Shared Tasks',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _hideForToday,
                    tooltip: 'Hide for today',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Stats
              Row(
                children: [
                  _StatChip(
                    label: 'To Do',
                    count: unclaimedCount,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    label: 'In Progress',
                    count: claimedCount,
                    color: Colors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Top tasks preview
              ...topTasks.map((task) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          task.priority == TaskPriority.urgent
                              ? Icons.priority_high
                              : Icons.circle_outlined,
                          size: 16,
                          color: task.priority == TaskPriority.urgent
                              ? AppTheme.urgentColor
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            task.title,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )),

              const SizedBox(height: 16),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.onFocusMode,
                      icon: const Icon(Icons.filter_center_focus, size: 18),
                      label: const Text('Focus Mode'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _hideForToday,
                    child: const Text('Hide for today'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

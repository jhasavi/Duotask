import 'package:flutter/material.dart';
import '../models/task.dart';
import '../utils/enhanced_theme.dart';
import '../services/smart_suggestions_service.dart';

/// Analytics dashboard showing task insights and productivity metrics
class AnalyticsDashboard extends StatefulWidget {
  final List<DuoTask> tasks;
  final String userId;
  final bool isLoading;

  const AnalyticsDashboard({
    super.key,
    required this.tasks,
    required this.userId,
    this.isLoading = false,
  });

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  TaskInsights? _insights;
  bool _isLoadingInsights = false;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  @override
  void didUpdateWidget(AnalyticsDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tasks != widget.tasks) {
      _loadInsights();
    }
  }

  Future<void> _loadInsights() async {
    setState(() => _isLoadingInsights = true);
    
    try {
      final insights = await SmartSuggestionsService().getTaskInsights(widget.userId);
      setState(() => _insights = insights);
    } catch (e) {
      // Handle error silently for now
    } finally {
      setState(() => _isLoadingInsights = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading || _isLoadingInsights) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(EnhancedTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: EnhancedTheme.spacing24),
          _buildOverviewCards(),
          const SizedBox(height: EnhancedTheme.spacing24),
          _buildTaskDistribution(),
          const SizedBox(height: EnhancedTheme.spacing24),
          _buildProductivityInsights(),
          const SizedBox(height: EnhancedTheme.spacing24),
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.analytics,
          color: Theme.of(context).colorScheme.primary,
          size: 28,
        ),
        const SizedBox(width: EnhancedTheme.spacing12),
        Text(
          'Analytics',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: _loadInsights,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh analytics',
        ),
      ],
    );
  }

  Widget _buildOverviewCards() {
    final totalTasks = widget.tasks.length;
    final completedTasks = widget.tasks.where((t) => t.status == TaskStatus.done).length;
    final urgentTasks = widget.tasks.where((t) => t.urgent).length;
    final todayTasks = widget.tasks.where((t) {
      if (t.dueDate == null) return false;
      final today = DateTime.now();
      final taskDate = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return taskDate == DateTime(today.year, today.month, today.day);
    }).length;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: EnhancedTheme.spacing16,
      mainAxisSpacing: EnhancedTheme.spacing16,
      childAspectRatio: 1.2,
      children: [
        _buildMetricCard(
          'Total Tasks',
          totalTasks.toString(),
          Icons.task_alt,
          Colors.blue,
        ),
        _buildMetricCard(
          'Completed',
          completedTasks.toString(),
          Icons.check_circle,
          Colors.green,
        ),
        _buildMetricCard(
          'Urgent',
          urgentTasks.toString(),
          Icons.priority_high,
          Colors.red,
        ),
        _buildMetricCard(
          'Today',
          todayTasks.toString(),
          Icons.today,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(EnhancedTheme.spacing16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(EnhancedTheme.radius16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: EnhancedTheme.shadowSmall,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 32,
          ),
          const SizedBox(height: EnhancedTheme.spacing8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskDistribution() {
    final statusCounts = <TaskStatus, int>{};
    for (final status in TaskStatus.values) {
      statusCounts[status] = widget.tasks.where((t) => t.status == status).length;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Task Distribution',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: EnhancedTheme.spacing16),
        Container(
          padding: const EdgeInsets.all(EnhancedTheme.spacing16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(EnhancedTheme.radius16),
            boxShadow: EnhancedTheme.shadowSmall,
          ),
          child: Column(
            children: statusCounts.entries.map((entry) {
              final status = entry.key;
              final count = entry.value;
              final total = widget.tasks.length;
              final percentage = total > 0 ? (count / total * 100) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: EnhancedTheme.spacing12),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: EnhancedTheme.getTaskStatusColor(status.name, context),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: EnhancedTheme.spacing12),
                    Expanded(
                      child: Text(
                        _getStatusLabel(status),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '$count (${percentage.toStringAsFixed(1)}%)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildProductivityInsights() {
    if (_insights == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Productivity Insights',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: EnhancedTheme.spacing16),
        Container(
          padding: const EdgeInsets.all(EnhancedTheme.spacing16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(EnhancedTheme.radius16),
            boxShadow: EnhancedTheme.shadowSmall,
          ),
          child: Column(
            children: [
              _buildInsightRow(
                'Peak Productivity',
                _insights!.peakProductivityTime,
                Icons.access_time,
              ),
              const Divider(),
              _buildInsightRow(
                'Average Tasks/Day',
                _insights!.averageTasksPerDay.toStringAsFixed(1),
                Icons.trending_up,
              ),
              const Divider(),
              _buildInsightRow(
                'Completion Rate',
                '${(_insights!.completionRate * 100).toStringAsFixed(1)}%',
                Icons.check_circle_outline,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: EnhancedTheme.spacing8),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: EnhancedTheme.spacing12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final recentTasks = widget.tasks
        .where((t) => t.status == TaskStatus.done)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (recentTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: EnhancedTheme.spacing16),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(EnhancedTheme.radius16),
            boxShadow: EnhancedTheme.shadowSmall,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentTasks.take(5).length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final task = recentTasks[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withOpacity(0.1),
                  child: Icon(
                    Icons.check,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                title: Text(
                  task.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  _formatDate(task.updatedAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: task.urgent
                    ? Icon(
                        Icons.priority_high,
                        color: Colors.red,
                        size: 16,
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  String _getStatusLabel(TaskStatus status) {
    switch (status) {
      case TaskStatus.unclaimed:
        return 'Unclaimed';
      case TaskStatus.claimed:
        return 'In Progress';
      case TaskStatus.done:
        return 'Completed';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}

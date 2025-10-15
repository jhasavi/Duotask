import 'package:flutter/material.dart';
import '../models/task.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import 'enhanced_task_bubble.dart';

/// Modern dashboard with improved layout and organization
class ModernDashboard extends StatelessWidget {
  final List<DuoTask> tasks;
  final String? currentUserId;
  final bool partnerOnline;
  final bool isLoading;
  final String? selectedFilter;
  final Function(DuoTask)? onTaskTap;
  final Function(DuoTask)? onTaskLongPress;
  final Function(DuoTask)? onTaskClaim;
  final Function(DuoTask)? onTaskComplete;
  final Function(DuoTask)? onTaskDelete;
  final Function(DuoTask)? onTaskRename;
  final Function(DuoTask)? onTaskOpenChat;
  final Function(DuoTask)? onTaskHandoff;
  final Map<String, bool> handoffPendingMap;
  final VoidCallback? onAddTask;
  final VoidCallback? onRefresh;
  final Function(String)? onFilterChanged;

  const ModernDashboard({
    super.key,
    required this.tasks,
    this.currentUserId,
    this.partnerOnline = false,
    this.isLoading = false,
    this.selectedFilter,
    this.onTaskTap,
    this.onTaskLongPress,
    this.onTaskClaim,
    this.onTaskComplete,
    this.onTaskDelete,
    this.onTaskRename,
    this.onTaskOpenChat,
    this.onTaskHandoff,
    this.handoffPendingMap = const {},
    this.onAddTask,
    this.onRefresh,
    this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // App bar
          _buildAppBar(context),
          
          // Stats cards
          _buildStatsSection(context),
          
          // Filter chips
          _buildFilterSection(context),
          
          // Tasks grid
          _buildTasksSection(context),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'DuoTask',
          style: AppTheme.headlineStyle.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.secondaryContainer,
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: onRefresh,
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            // Navigate to settings
          },
        ),
      ],
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    final urgentTasks = tasks.where((t) => t.urgent).length;
    final todayTasks = tasks.where((t) {
      if (t.dueDate == null) return false;
      final today = DateTime.now();
      final taskDate = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return taskDate == DateTime(today.year, today.month, today.day);
    }).length;
    final completedTasks = tasks.where((t) => t.status == TaskStatus.done).length;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'Urgent',
                urgentTasks.toString(),
                Icons.priority_high,
                Colors.red,
              ),
            ),
            const SizedBox(width: AppConstants.defaultPadding),
            Expanded(
              child: _buildStatCard(
                context,
                'Today',
                todayTasks.toString(),
                Icons.today,
                Colors.orange,
              ),
            ),
            const SizedBox(width: AppConstants.defaultPadding),
            Expanded(
              child: _buildStatCard(
                context,
                'Completed',
                completedTasks.toString(),
                Icons.check_circle,
                Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.headlineStyle.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: AppTheme.captionStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context) {
    final filters = [
      {'key': 'all', 'label': 'All', 'icon': Icons.list},
      {'key': 'mine', 'label': 'Mine', 'icon': Icons.person},
      {'key': 'partner', 'label': 'Partner', 'icon': Icons.people},
      {'key': 'urgent', 'label': 'Urgent', 'icon': Icons.priority_high},
    ];

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.defaultPadding,
          vertical: AppConstants.smallPadding,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((filter) {
              final isSelected = selectedFilter == filter['key'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        filter['icon'] as IconData,
                        size: 16,
                        color: isSelected 
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(filter['label'] as String),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (_) => onFilterChanged?.call(filter['key'] as String),
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  checkmarkColor: Theme.of(context).colorScheme.onPrimary,
                  side: BorderSide(
                    color: isSelected 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildTasksSection(BuildContext context) {
    if (isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (tasks.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(context),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.0,
          crossAxisSpacing: AppConstants.defaultPadding,
          mainAxisSpacing: AppConstants.defaultPadding,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final task = tasks[index];
            final handoffPending = handoffPendingMap[task.id] ?? false;
            
            return EnhancedTaskBubble(
              task: task,
              currentUserId: currentUserId,
              partnerOnline: partnerOnline,
              onTap: onTaskTap != null ? () => onTaskTap!(task) : null,
              onLongPress: onTaskLongPress != null ? () => onTaskLongPress!(task) : null,
              onClaim: onTaskClaim != null ? () => onTaskClaim?.call(task) : null,
              onComplete: onTaskComplete != null ? () => onTaskComplete?.call(task) : null,
              onDelete: onTaskDelete != null ? () => onTaskDelete?.call(task) : null,
              onRename: onTaskRename != null ? () => onTaskRename?.call(task) : null,
              onOpenChat: onTaskOpenChat != null ? () => onTaskOpenChat?.call(task) : null,
              onHandoff: onTaskHandoff != null ? () => onTaskHandoff?.call(task) : null,
              handoffPending: handoffPending,
            );
          },
          childCount: tasks.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.task_alt_outlined,
                size: 60,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No tasks yet',
              style: AppTheme.titleStyle.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first task to get started',
              style: AppTheme.bodyStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onAddTask,
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onAddTask,
      icon: const Icon(Icons.add),
      label: const Text('Add Task'),
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
    );
  }
}

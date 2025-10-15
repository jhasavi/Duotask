import 'package:flutter/material.dart';
import '../models/task.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import 'modern_task_bubble.dart';

/// Modern task list with improved layout and visual hierarchy
class ModernTaskList extends StatelessWidget {
  final List<DuoTask> tasks;
  final String? currentUserId;
  final bool partnerOnline;
  final Function(DuoTask)? onTaskTap;
  final Function(DuoTask)? onTaskLongPress;
  final Function(DuoTask)? onTaskClaim;
  final Function(DuoTask)? onTaskComplete;
  final Function(DuoTask)? onTaskDelete;
  final Function(DuoTask)? onTaskRename;
  final Function(DuoTask)? onTaskOpenChat;
  final Function(DuoTask)? onTaskHandoff;
  final Map<String, bool> handoffPendingMap;
  final bool isLoading;
  final String? emptyMessage;
  final String? emptySubtitle;

  const ModernTaskList({
    super.key,
    required this.tasks,
    this.currentUserId,
    this.partnerOnline = false,
    this.onTaskTap,
    this.onTaskLongPress,
    this.onTaskClaim,
    this.onTaskComplete,
    this.onTaskDelete,
    this.onTaskRename,
    this.onTaskOpenChat,
    this.onTaskHandoff,
    this.handoffPendingMap = const {},
    this.isLoading = false,
    this.emptyMessage,
    this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (tasks.isEmpty) {
      return _buildEmptyState();
    }

    return _buildTaskGrid();
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading tasks...'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.task_alt_outlined,
                size: 60,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              emptyMessage ?? 'No tasks yet',
              style: AppTheme.titleStyle.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              emptySubtitle ?? 'Create your first task to get started',
              style: AppTheme.bodyStyle.copyWith(
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskGrid() {
    return CustomScrollView(
      slivers: [
        // Task grid
        SliverPadding(
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
                
                return ModernTaskBubble(
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
        ),
        
        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }
}

/// Modern task list with sections
class ModernTaskListWithSections extends StatelessWidget {
  final Map<String, List<DuoTask>> tasksBySection;
  final String? currentUserId;
  final bool partnerOnline;
  final Function(DuoTask)? onTaskTap;
  final Function(DuoTask)? onTaskLongPress;
  final Function(DuoTask)? onTaskClaim;
  final Function(DuoTask)? onTaskComplete;
  final Function(DuoTask)? onTaskDelete;
  final Function(DuoTask)? onTaskRename;
  final Function(DuoTask)? onTaskOpenChat;
  final Function(DuoTask)? onTaskHandoff;
  final Map<String, bool> handoffPendingMap;
  final bool isLoading;

  const ModernTaskListWithSections({
    super.key,
    required this.tasksBySection,
    this.currentUserId,
    this.partnerOnline = false,
    this.onTaskTap,
    this.onTaskLongPress,
    this.onTaskClaim,
    this.onTaskComplete,
    this.onTaskDelete,
    this.onTaskRename,
    this.onTaskOpenChat,
    this.onTaskHandoff,
    this.handoffPendingMap = const {},
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (tasksBySection.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      itemCount: tasksBySection.length,
      itemBuilder: (context, index) {
        final section = tasksBySection.keys.elementAt(index);
        final tasks = tasksBySection[section]!;
        
        return _buildSection(section, tasks);
      },
    );
  }

  Widget _buildSection(String sectionTitle, List<DuoTask> tasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppConstants.defaultPadding,
            horizontal: AppConstants.smallPadding,
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: _getSectionColor(sectionTitle),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                sectionTitle,
                style: AppTheme.titleStyle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getSectionColor(sectionTitle).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${tasks.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getSectionColor(sectionTitle),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Tasks grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.0,
            crossAxisSpacing: AppConstants.defaultPadding,
            mainAxisSpacing: AppConstants.defaultPadding,
          ),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            final handoffPending = handoffPendingMap[task.id] ?? false;
            
            return ModernTaskBubble(
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
        ),
        
        const SizedBox(height: AppConstants.largePadding),
      ],
    );
  }

  Widget _buildEmptyState() {
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
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.task_alt_outlined,
                size: 60,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No tasks found',
              style: AppTheme.titleStyle.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or create a new task',
              style: AppTheme.bodyStyle.copyWith(
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getSectionColor(String sectionTitle) {
    switch (sectionTitle.toLowerCase()) {
      case 'urgent':
        return Colors.red;
      case 'today':
        return Colors.orange;
      case 'upcoming':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';
import '../widgets/task_bubble.dart';
import '../services/app_dependencies.dart';
import '../utils/constants.dart';

/// Widget responsible for displaying the list of tasks
class TaskListWidget extends StatefulWidget {
  final bool isPaired;
  final String filter;
  final String sort;
  final bool todayOnly;
  final String tabType;
  final Function(DuoTask) onTaskTap;
  final Function(DuoTask) onTaskRename;
  final Function(DuoTask) onTaskClaim;
  final Function(DuoTask) onTaskComplete;
  final Function(DuoTask) onTaskUndo;
  final Function(DuoTask) onTaskDelete;
  final Function(DuoTask) onTaskToggleRepeat;
  final Function(DuoTask) onTaskToggleUrgent;
  final Function(DuoTask) onTaskOpenChat;
  final Function(DuoTask)? onTaskHandoff;

  const TaskListWidget({
    super.key,
    required this.isPaired,
    required this.filter,
    required this.sort,
    this.todayOnly = false,
    required this.tabType,
    required this.onTaskTap,
    required this.onTaskRename,
    required this.onTaskClaim,
    required this.onTaskComplete,
    required this.onTaskUndo,
    required this.onTaskDelete,
    required this.onTaskToggleRepeat,
    required this.onTaskToggleUrgent,
    required this.onTaskOpenChat,
    this.onTaskHandoff,
  });

  @override
  State<TaskListWidget> createState() => _TaskListWidgetState();
}

class _TaskListWidgetState extends State<TaskListWidget> {
  String? _safeUserId() {
    return Supabase.instance.client.auth.currentUser?.id;
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.of(context);
    final currentUserId = _safeUserId();

    if (currentUserId == null) {
      return const Center(
        child: Text('Please log in to view tasks'),
      );
    }

    return StreamBuilder<List<DuoTask>>(
      stream: deps.tasks.watchTasks(
        userId: currentUserId,
        filter: widget.filter,
        sort: widget.sort,
        todayOnly: widget.todayOnly,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading tasks: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final tasks = snapshot.data!;

        if (tasks.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return _buildTaskItem(task, deps);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    if (widget.filter == 'mine') {
      message = 'No tasks assigned to you';
      icon = Icons.person_outline;
    } else if (widget.filter == 'partner') {
      message = 'No tasks assigned to your partner';
      icon = Icons.people_outline;
    } else if (widget.todayOnly) {
      message = 'No tasks for today';
      icon = Icons.today_outlined;
    } else {
      message = 'No tasks yet';
      icon = Icons.task_alt;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(DuoTask task, AppDependencies deps) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
      child: StreamBuilder<bool>(
        stream: _getPartnerOnlineStream(task, deps),
        builder: (context, presenceSnap) {
          final partnerOnline = presenceSnap.data ?? false;

          return TaskBubble(
            task: task,
            tabType: widget.tabType,
            onTap: () => widget.onTaskTap(task),
          );
        },
      ),
    );
  }

  Stream<bool> _getPartnerOnlineStream(DuoTask task, AppDependencies deps) {
    return const Stream<bool>.empty();
  }

  dynamic _findPendingHandoff(List items) {
    final currentUserId = _safeUserId();
    if (currentUserId == null) return null;

    for (final h in items) {
      final status = (h.status ?? '').toString();
      final toUser = (h.toUser ?? h.to_user).toString();

      if (status == AppConstants.handoffStatusProposed &&
          toUser == currentUserId) {
        return h;
      }
    }
    return null;
  }

  Future<void> _handleHandoffReview(dynamic pending) async {
    // Handoff functionality removed for simplicity
  }
}

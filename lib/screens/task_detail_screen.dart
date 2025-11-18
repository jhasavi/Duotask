import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/auth_service.dart';
import '../config/theme.dart';
import '../utils/haptic_helper.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;

  const TaskDetailScreen({
    super.key,
    required this.task,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Task _task;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _selectedDueDate;
  TaskPriority _selectedPriority = TaskPriority.normal;
  TaskRecurrence _selectedRecurrence = TaskRecurrence.none;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _titleController.text = _task.title;
    _descriptionController.text = _task.description ?? '';
    _selectedDueDate = _task.dueDate;
    _selectedPriority = _task.priority;
    _selectedRecurrence = _task.recurrence;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDueDate ?? DateTime.now()),
      );

      if (time != null) {
        setState(() {
          _selectedDueDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    final taskService = context.read<TaskService>();
    final updatedTask = _task.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      dueDate: _selectedDueDate,
      priority: _selectedPriority,
      recurrence: _selectedRecurrence,
    );

    final success = await taskService.updateTask(updatedTask);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task updated')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(taskService.errorMessage ?? 'Failed to update task'),
          ),
        );
      }
    }
  }

  Future<void> _deleteTask() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await HapticHelper.delete();
              if (context.mounted) {
                Navigator.pop(context, true);
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.urgentColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final taskService = context.read<TaskService>();
    final success = await taskService.deleteTask(_task.id);

    if (mounted) {
      if (success) {
        await HapticHelper.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task deleted')),
        );
        Navigator.pop(context);
      } else {
        await HapticHelper.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(taskService.errorMessage ?? 'Failed to delete task'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final isOwner = _task.createdById == authService.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteTask,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status badge
            Row(
              children: [
                _StatusBadge(status: _task.status),
                const Spacer(),
                if (_task.completedAt != null)
                  Text(
                    'Completed ${DateFormat('MMM d, h:mm a').format(_task.completedAt!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.title),
              ),
              enabled: isOwner,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              enabled: isOwner,
              maxLines: 4,
            ),
            const SizedBox(height: 16),

            // Priority
            DropdownButtonFormField<TaskPriority>(
              value: _selectedPriority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                prefixIcon: Icon(Icons.flag),
              ),
              items: TaskPriority.values.map((priority) {
                return DropdownMenuItem(
                  value: priority,
                  child: Row(
                    children: [
                      Icon(
                        Icons.flag,
                        color: priority == TaskPriority.urgent
                            ? AppTheme.urgentColor
                            : AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(priority.displayName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: isOwner
                  ? (value) {
                      if (value != null) {
                        setState(() {
                          _selectedPriority = value;
                        });
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 16),

            // Recurrence
            DropdownButtonFormField<TaskRecurrence>(
              value: _selectedRecurrence,
              decoration: const InputDecoration(
                labelText: 'Recurrence',
                prefixIcon: Icon(Icons.repeat),
              ),
              items: TaskRecurrence.values.map((recurrence) {
                return DropdownMenuItem(
                  value: recurrence,
                  child: Text(recurrence.displayName),
                );
              }).toList(),
              onChanged: isOwner
                  ? (value) {
                      if (value != null) {
                        setState(() {
                          _selectedRecurrence = value;
                        });
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 16),

            // Due date
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(
                _selectedDueDate != null
                    ? DateFormat('MMM d, y h:mm a').format(_selectedDueDate!)
                    : 'No due date',
              ),
              subtitle: const Text('Due date'),
              trailing: isOwner
                  ? IconButton(
                      icon: Icon(
                        _selectedDueDate != null ? Icons.edit : Icons.add,
                      ),
                      onPressed: _selectDueDate,
                    )
                  : null,
              contentPadding: EdgeInsets.zero,
            ),

            if (_selectedDueDate != null && isOwner)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedDueDate = null;
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear due date'),
              ),
            const SizedBox(height: 32),

            // Save button
            if (isOwner)
              ElevatedButton.icon(
                onPressed: _saveTask,
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
              ),
            const SizedBox(height: 16),

            // Metadata
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Information',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Divider(),
                    _InfoRow(
                      label: 'Created',
                      value: DateFormat('MMM d, y h:mm a').format(_task.createdAt),
                    ),
                    if (_task.updatedAt != null)
                      _InfoRow(
                        label: 'Updated',
                        value: DateFormat('MMM d, y h:mm a').format(_task.updatedAt!),
                      ),
                    _InfoRow(
                      label: 'Type',
                      value: _task.isPersonal ? 'Personal' : 'Shared',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TaskStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (status) {
      case TaskStatus.unclaimed:
        color = AppTheme.unclaimedPersonalColor;
        icon = Icons.circle_outlined;
        break;
      case TaskStatus.claimed:
        color = AppTheme.claimedColor;
        icon = Icons.access_time;
        break;
      case TaskStatus.completed:
        color = AppTheme.completedColor;
        icon = Icons.check_circle;
        break;
    }

    return Chip(
      avatar: Icon(icon, color: color, size: 20),
      label: Text(
        status.displayName,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color, width: 1),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

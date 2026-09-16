import 'package:flutter/material.dart';
import '../models/task.dart';
import '../config/theme.dart';

/// Dialog for creating a new task with Personal/Group visibility toggle
/// Only shows toggle when user is paired
class TaskCreationDialog extends StatefulWidget {
  final bool isPaired;
  final String? pairId;
  final String defaultVisibility;
  final Function(
    String title,
    TaskVisibility visibility, {
    TaskPriority priority,
    TaskRecurrence recurrence,
    DateTime? recurrenceEndDate,
    List<String> tags,
  }) onCreateTask;

  const TaskCreationDialog({
    super.key,
    required this.isPaired,
    this.pairId,
    this.defaultVisibility = 'personal',
    required this.onCreateTask,
  });

  @override
  State<TaskCreationDialog> createState() => _TaskCreationDialogState();
}

class _TaskCreationDialogState extends State<TaskCreationDialog> {
  final _taskController = TextEditingController();
  final _tagController = TextEditingController();
  late TaskVisibility _selectedVisibility;
  TaskPriority _selectedPriority = TaskPriority.normal;
  TaskRecurrence _selectedRecurrence = TaskRecurrence.none;
  DateTime? _recurrenceEndDate;
  final List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _selectedVisibility = widget.defaultVisibility == 'group'
        ? TaskVisibility.group
        : TaskVisibility.personal;
  }

  @override
  void dispose() {
    _taskController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty || _tags.contains(tag)) {
      _tagController.clear();
      return;
    }
    setState(() {
      _tags.add(tag);
      _tagController.clear();
    });
  }

  Future<void> _pickRecurrenceEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _recurrenceEndDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _recurrenceEndDate = picked);
    }
  }

  void _createTask() {
    final text = _taskController.text.trim();
    if (text.isEmpty) return;

    widget.onCreateTask(
      text,
      _selectedVisibility,
      priority: _selectedPriority,
      recurrence: _selectedRecurrence,
      recurrenceEndDate: _selectedRecurrence == TaskRecurrence.none
          ? null
          : _recurrenceEndDate,
      tags: _tags,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Text(
              'Create New Task',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),

            // Task input field
            TextField(
              controller: _taskController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g., "Grocery @6pm"',
                labelText: 'Task',
                prefixIcon: Icon(Icons.task_alt),
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _createTask(),
            ),
            const SizedBox(height: 24),

            // Personal/Group toggle (only shown when paired)
            if (widget.isPaired) ...[
              Text(
                'Task Type',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 12),
              SegmentedButton<TaskVisibility>(
                segments: const [
                  ButtonSegment(
                    value: TaskVisibility.personal,
                    label: Text('Personal'),
                    icon: Icon(Icons.person),
                  ),
                  ButtonSegment(
                    value: TaskVisibility.group,
                    label: Text('Group'),
                    icon: Icon(Icons.people),
                  ),
                ],
                selected: {_selectedVisibility},
                onSelectionChanged: (Set<TaskVisibility> newSelection) {
                  setState(() {
                    _selectedVisibility = newSelection.first;
                  });
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.comfortable,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedVisibility == TaskVisibility.personal
                    ? 'Only you can see this task'
                    : 'Both you and your partner can see this task',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
              ),
              const SizedBox(height: 24),
            ],

            // Priority selection
            Text(
              'Priority',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            SegmentedButton<TaskPriority>(
              segments: const [
                ButtonSegment(
                  value: TaskPriority.normal,
                  label: Text('Normal'),
                  icon: Icon(Icons.flag_outlined),
                ),
                ButtonSegment(
                  value: TaskPriority.urgent,
                  label: Text('Urgent'),
                  icon: Icon(Icons.priority_high),
                ),
              ],
              selected: {_selectedPriority},
              onSelectionChanged: (Set<TaskPriority> newSelection) {
                setState(() {
                  _selectedPriority = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 16),

            // Recurrence selection
            Text(
              'Repeat',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            SegmentedButton<TaskRecurrence>(
              segments: const [
                ButtonSegment(
                  value: TaskRecurrence.none,
                  label: Text('None'),
                ),
                ButtonSegment(
                  value: TaskRecurrence.daily,
                  label: Text('Daily'),
                  icon: Icon(Icons.today),
                ),
                ButtonSegment(
                  value: TaskRecurrence.weekly,
                  label: Text('Weekly'),
                  icon: Icon(Icons.date_range),
                ),
                ButtonSegment(
                  value: TaskRecurrence.monthly,
                  label: Text('Monthly'),
                  icon: Icon(Icons.calendar_month),
                ),
                ButtonSegment(
                  value: TaskRecurrence.yearly,
                  label: Text('Yearly'),
                  icon: Icon(Icons.event_repeat),
                ),
              ],
              selected: {_selectedRecurrence},
              onSelectionChanged: (Set<TaskRecurrence> newSelection) {
                setState(() {
                  _selectedRecurrence = newSelection.first;
                  if (_selectedRecurrence == TaskRecurrence.none) {
                    _recurrenceEndDate = null;
                  }
                });
              },
            ),
            if (_selectedRecurrence != TaskRecurrence.none) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickRecurrenceEndDate,
                child: Row(
                  children: [
                    const Icon(Icons.event_busy, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _recurrenceEndDate != null
                          ? 'Ends ${_recurrenceEndDate!.month}/${_recurrenceEndDate!.day}/${_recurrenceEndDate!.year}'
                          : 'Set an end date (optional)',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_recurrenceEndDate != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () =>
                            setState(() => _recurrenceEndDate = null),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Tags
            Text(
              'Tags',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagController,
              decoration: const InputDecoration(
                hintText: 'e.g., "home" — press Enter to add',
                prefixIcon: Icon(Icons.label_outline),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: _addTag,
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _tags
                    .map((tag) => Chip(
                          label: Text(tag),
                          onDeleted: () => setState(() => _tags.remove(tag)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _createTask,
                  child: const Text('Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

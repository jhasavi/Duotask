import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskDialog extends StatefulWidget {
  final DuoTask? task;
  final Function(String title, DateTime? dueDate, TaskStatus status, bool urgent) onSubmit;

  const TaskDialog({
    super.key,
    this.task,
    required this.onSubmit,
  });

  @override
  State<TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<TaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  DateTime? _selectedDate;
  TaskStatus _selectedStatus = TaskStatus.unclaimed;
  bool _isUrgent = false;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _selectedStatus = widget.task!.status;
      _selectedDate = widget.task!.dueDate;
      _isUrgent = widget.task!.urgent;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onSubmit(
        _titleController.text.trim(),
        _selectedDate,
        _selectedStatus,
        _isUrgent,
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.task == null ? 'Create New Task' : 'Edit Task',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                style: const TextStyle(color: Colors.black87),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a task title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text(
                        'Mark as Urgent',
                        style: TextStyle(color: Colors.black87),
                      ),
                      value: _isUrgent,
                      onChanged: (value) {
                        setState(() {
                          _isUrgent = value ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedStatus.name,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                        labelStyle: TextStyle(color: Colors.grey),
                      ),
                      style: const TextStyle(color: Colors.black87),
                      items: const [
                        DropdownMenuItem(value: 'unclaimed', child: Text('Pending')),
                        DropdownMenuItem(value: 'claimed', child: Text('In Progress')),
                        DropdownMenuItem(value: 'done', child: Text('Completed')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = TaskStatus.values.firstWhere(
                            (e) => e.name == value,
                            orElse: () => TaskStatus.unclaimed,
                          );
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _selectDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _selectedDate == null 
                            ? 'Set Due Date' 
                            : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedDate == null 
                            ? Colors.grey[300] 
                            : Colors.blue,
                        foregroundColor: _selectedDate == null 
                            ? Colors.grey[600] 
                            : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(widget.task == null ? 'Create' : 'Update'),
        ),
      ],
    );
  }
}

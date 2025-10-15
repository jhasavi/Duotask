import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../utils/validation.dart';

/// Smart task form with modern design and intelligent features
class SmartTaskForm extends StatefulWidget {
  final DuoTask? task;
  final Function(String title, DateTime? dueDate, bool urgent, RepeatType repeatType) onSubmit;
  final VoidCallback? onCancel;
  final bool isLoading;
  final String? tabType; // 'shared', 'personal', 'partner'
  final bool isPaired;
  final String? partnerName;

  const SmartTaskForm({
    super.key,
    this.task,
    required this.onSubmit,
    this.onCancel,
    this.isLoading = false,
    this.tabType,
    this.isPaired = false,
    this.partnerName,
  });

  @override
  State<SmartTaskForm> createState() => _SmartTaskFormState();
}

class _SmartTaskFormState extends State<SmartTaskForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _focusNode = FocusNode();
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isUrgent = false;
  RepeatType _repeatType = RepeatType.none;
  bool _showAdvancedOptions = false;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _selectedDate = widget.task!.dueDate;
      _selectedTime = null; // No separate time field in new model
      _isUrgent = widget.task!.urgent;
      _repeatType = widget.task!.repeatType;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final title = _titleController.text.trim();
      DateTime? dueDateTime;
      
      if (_selectedDate != null) {
        if (_selectedTime != null) {
          dueDateTime = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            _selectedTime!.hour,
            _selectedTime!.minute,
          );
        } else {
          dueDateTime = _selectedDate;
        }
      }
      
      widget.onSubmit(title, dueDateTime, _isUrgent, _repeatType);
    }
  }

  void _selectDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDate ?? now;
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _selectTime() async {
    final initialTime = _selectedTime ?? TimeOfDay.now();
    
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _clearDateTime() {
    setState(() {
      _selectedDate = null;
      _selectedTime = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.largeBorderRadius),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  widget.task != null ? Icons.edit : Icons.add_task,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.task != null ? 'Edit Task' : _getTaskCreationTitle(),
                        style: AppTheme.titleStyle.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.task == null && widget.tabType != null)
                        Text(
                          _getTaskCreationSubtitle(),
                          style: AppTheme.bodyStyle.copyWith(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Title field
            _buildTitleField(),
            
            const SizedBox(height: 20),
            
            // Quick actions
            _buildQuickActions(),
            
            const SizedBox(height: 20),
            
            // Advanced options toggle
            _buildAdvancedToggle(),
            
            if (_showAdvancedOptions) ...[
              const SizedBox(height: 20),
              _buildAdvancedOptions(),
            ],
            
            const SizedBox(height: 24),
            
            // Submit button
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      focusNode: _focusNode,
      decoration: InputDecoration(
        labelText: 'Task title',
        hintText: 'What needs to be done?',
        prefixIcon: const Icon(Icons.task_alt),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a task title';
        }
        if (value.trim().length < 3) {
          return 'Task title must be at least 3 characters';
        }
        return null;
      },
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submitForm(),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        // Urgent toggle
        Expanded(
          child: _buildActionChip(
            icon: Icons.priority_high,
            label: 'Urgent',
            isSelected: _isUrgent,
            onTap: () => setState(() => _isUrgent = !_isUrgent),
            color: Colors.red,
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Due date
        Expanded(
          child: _buildActionChip(
            icon: Icons.calendar_today,
            label: _selectedDate != null 
                ? _formatDate(_selectedDate!)
                : 'Due date',
            isSelected: _selectedDate != null,
            onTap: _selectDate,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withOpacity(0.1)
              : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedToggle() {
    return InkWell(
      onTap: () => setState(() => _showAdvancedOptions = !_showAdvancedOptions),
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        child: Row(
          children: [
            Icon(
              Icons.settings,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'Advanced options',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Icon(
              _showAdvancedOptions ? Icons.expand_less : Icons.expand_more,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedOptions() {
    return Column(
      children: [
        // Time picker
        if (_selectedDate != null) ...[
          Row(
            children: [
              Expanded(
                child: _buildActionChip(
                  icon: Icons.access_time,
                  label: _selectedTime != null 
                      ? _selectedTime!.format(context)
                      : 'Add time',
                  isSelected: _selectedTime != null,
                  onTap: _selectTime,
                  color: Colors.green,
                ),
              ),
              if (_selectedTime != null) ...[
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => setState(() => _selectedTime = null),
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear time',
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],
        
        // Repeat options
        _buildRepeatOptions(),
        
        // Clear date button
        if (_selectedDate != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _clearDateTime,
            icon: const Icon(Icons.clear),
            label: const Text('Clear due date'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRepeatOptions() {
    final repeatOptions = [
      {'type': RepeatType.none, 'label': 'No repeat', 'icon': Icons.close},
      {'type': RepeatType.daily, 'label': 'Daily', 'icon': Icons.repeat},
      {'type': RepeatType.weekly, 'label': 'Weekly', 'icon': Icons.repeat_one},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Repeat',
          style: AppTheme.bodyStyle.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: repeatOptions.map((option) {
            final isSelected = _repeatType == option['type'];
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    option['icon'] as IconData,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(option['label'] as String),
                ],
              ),
              selected: isSelected,
              onSelected: (_) => setState(() => _repeatType = option['type'] as RepeatType),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final isSharedTask = _isSharedTaskRequested();
    final canCreateSharedTask = widget.isPaired;
    final canCreatePersonalTask = widget.tabType?.toLowerCase() == 'personal' || !widget.isPaired;
    
    // Allow submission if:
    // 1. Loading is false
    // 2. Either we can create shared tasks (when paired) OR we can create personal tasks
    final canSubmit = !widget.isLoading && (canCreateSharedTask || canCreatePersonalTask);
    
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: canSubmit ? _submitForm : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _getSubmitButtonColor(),
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
        ),
        child: widget.isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                _getSubmitButtonText(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  bool _isSharedTaskRequested() {
    return widget.tabType?.toLowerCase() == 'shared' || 
           (widget.tabType?.toLowerCase() == 'partner' && widget.isPaired);
  }

  Color _getSubmitButtonColor() {
    if (widget.isLoading) return Theme.of(context).colorScheme.primary;
    
    final isSharedTask = _isSharedTaskRequested();
    final canCreateSharedTask = widget.isPaired || widget.tabType?.toLowerCase() == 'personal';
    
    if (isSharedTask && !canCreateSharedTask) {
      return Colors.grey;
    }
    
    return Theme.of(context).colorScheme.primary;
  }

  String _getSubmitButtonText() {
    if (widget.task != null) return 'Update Task';
    
    switch (widget.tabType?.toLowerCase()) {
      case 'shared':
        if (widget.isPaired) {
          return 'Create Shared Task';
        } else {
          return 'Create Personal Task';
        }
      case 'personal':
        return 'Create Personal Task';
      case 'partner':
        if (widget.isPaired) {
          return 'Create Shared Task';
        } else {
          return 'Pair First';
        }
      default:
        return 'Create Task';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final taskDate = DateTime(date.year, date.month, date.day);

    if (taskDate == today) return 'Today';
    if (taskDate == tomorrow) return 'Tomorrow';
    
    return '${date.month}/${date.day}';
  }

  String _getTaskCreationTitle() {
    if (widget.task != null) return 'Edit Task';
    
    switch (widget.tabType?.toLowerCase()) {
      case 'shared':
        if (widget.isPaired && widget.partnerName != null) {
          return 'New Shared Task with ${widget.partnerName}';
        } else if (widget.isPaired) {
          return 'New Shared Task with Partner';
        } else {
          return 'New Personal Task';
        }
      case 'personal':
        return 'New Personal Task';
      case 'partner':
        if (!widget.isPaired) {
          return 'Pair First';
        } else {
          return 'New Shared Task with ${widget.partnerName ?? 'Partner'}';
        }
      default:
        return 'New Task';
    }
  }

  String _getTaskCreationSubtitle() {
    switch (widget.tabType?.toLowerCase()) {
      case 'shared':
        if (widget.isPaired) {
          return 'This task will be visible to both you and your partner';
        } else {
          return 'Pair with someone to create shared tasks';
        }
      case 'personal':
        return 'This task is only visible to you';
      case 'partner':
        if (!widget.isPaired) {
          return 'You need to pair with someone first';
        } else {
          return 'This task will be visible to both you and your partner';
        }
      default:
        return '';
    }
  }
}

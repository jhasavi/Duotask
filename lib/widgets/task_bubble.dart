import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task.dart';
import 'dart:async'; // Added for Timer

class TaskBubble extends StatefulWidget {
  final DuoTask task;
  final String tabType;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onStatusChange;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleUrgent;
  final VoidCallback? onReclaim; // New callback for reclaiming

  const TaskBubble({
    super.key,
    required this.task,
    required this.tabType,
    this.onTap,
    this.onLongPress,
    this.onStatusChange,
    this.onDelete,
    this.onToggleUrgent,
    this.onReclaim,
  });

  @override
  State<TaskBubble> createState() => _TaskBubbleState();
}

class _TaskBubbleState extends State<TaskBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  bool _isPressed = false;
  bool _isLongPressing = false;
  Timer? _longPressTimer;
  Timer? _doubleTapTimer;
  int _tapCount = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _longPressTimer?.cancel();
    _doubleTapTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    _tapCount++;
    
    // Cute bounce animation on tap
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    if (_tapCount == 1) {
      // First tap - show details
      _showTaskDetails();
      
      // Start double tap timer
      _doubleTapTimer = Timer(const Duration(milliseconds: 300), () {
        _tapCount = 0;
      });
    } else if (_tapCount == 2) {
      // Double tap - change status
      _doubleTapTimer?.cancel();
      _tapCount = 0;
      _cycleStatus();
    }
  }

  void _handleLongPressStart() {
    setState(() {
      _isLongPressing = true;
    });

    // Start long press timer
    _longPressTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _isLongPressing) {
        _showDeleteConfirmation();
      }
    });

    // Haptic feedback
    HapticFeedback.mediumImpact();
  }

  void _handleLongPressEnd() {
    setState(() {
      _isLongPressing = false;
    });
    _longPressTimer?.cancel();
  }

  void _cycleStatus() {
    // Determine next status based on current status and task type
    TaskStatus nextStatus;
    
    if (widget.tabType == 'shared') {
      // Shared tasks: Unclaimed → Claimed → Done → Unclaimed
      switch (widget.task.status) {
        case TaskStatus.unclaimed:
          nextStatus = TaskStatus.claimed;
          break;
        case TaskStatus.claimed:
          nextStatus = TaskStatus.done;
          break;
        case TaskStatus.done:
          nextStatus = TaskStatus.unclaimed;
          break;
      }
    } else {
      // Personal tasks: Unclaimed → Done → Unclaimed (skip claimed)
      switch (widget.task.status) {
        case TaskStatus.unclaimed:
          nextStatus = TaskStatus.done;
          break;
        case TaskStatus.claimed:
          nextStatus = TaskStatus.done;
          break;
        case TaskStatus.done:
          nextStatus = TaskStatus.unclaimed;
          break;
      }
    }

    // Call the status change callback
    widget.onStatusChange?.call();
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${widget.task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDelete?.call();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showTaskDetails() {
    // Show task details in a bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildTaskDetailsSheet(),
    );
  }

  Widget _buildTaskDetailsSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Task title
          Text(
            widget.task.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Task status
          Row(
            children: [
              Icon(
                _getStatusIcon(),
                color: _getStatusColor(),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _getStatusText(),
                style: TextStyle(
                  color: _getStatusColor(),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Due date if available
          if (widget.task.dueDate != null) ...[
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: widget.task.isOverdue ? Colors.red : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Due: ${_formatDate(widget.task.dueDate!)}',
                  style: TextStyle(
                    color: widget.task.isOverdue ? Colors.red : Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          
          // Action buttons
          Row(
            children: [
              // Status change button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _cycleStatus();
                  },
                  icon: Icon(_getNextStatusIcon()),
                  label: Text('Mark ${_getNextStatusText()}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getStatusColor(),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Reclaim button (only for shared tasks claimed by others)
              if (widget.tabType == 'shared' && 
                  widget.task.status == TaskStatus.claimed &&
                  widget.task.claimedBy != null) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showReclaimConfirmation();
                    },
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Reclaim'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ] else ...[
                const Expanded(child: SizedBox()),
              ],
            ],
          ),
          const SizedBox(height: 12),
          
          // Delete button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _showDeleteConfirmation();
              },
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text('Delete Task', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (widget.task.status) {
      case TaskStatus.unclaimed:
        return Icons.radio_button_unchecked;
      case TaskStatus.claimed:
        return Icons.person;
      case TaskStatus.done:
        return Icons.check_circle;
    }
  }

  IconData _getNextStatusIcon() {
    if (widget.tabType == 'shared') {
      switch (widget.task.status) {
        case TaskStatus.unclaimed:
          return Icons.person;
        case TaskStatus.claimed:
          return Icons.check_circle;
        case TaskStatus.done:
          return Icons.radio_button_unchecked;
      }
    } else {
      switch (widget.task.status) {
        case TaskStatus.unclaimed:
        case TaskStatus.claimed:
          return Icons.check_circle;
        case TaskStatus.done:
          return Icons.radio_button_unchecked;
      }
    }
  }

  String _getNextStatusText() {
    if (widget.tabType == 'shared') {
      switch (widget.task.status) {
        case TaskStatus.unclaimed:
          return 'Claimed';
        case TaskStatus.claimed:
          return 'Done';
        case TaskStatus.done:
          return 'Unclaimed';
      }
    } else {
      switch (widget.task.status) {
        case TaskStatus.unclaimed:
        case TaskStatus.claimed:
          return 'Done';
        case TaskStatus.done:
          return 'Unclaimed';
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);
    
    if (taskDate == today) {
      return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (taskDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  Color _getStatusColor() {
    switch (widget.task.status) {
      case TaskStatus.unclaimed:
        return Colors.grey[600]!;
      case TaskStatus.claimed:
        return Colors.orange;
      case TaskStatus.done:
        return Colors.green;
    }
  }

  String _getStatusText() {
    switch (widget.task.status) {
      case TaskStatus.unclaimed:
        return 'Unclaimed';
      case TaskStatus.claimed:
        return 'Claimed';
      case TaskStatus.done:
        return 'Completed';
    }
  }

  void _showReclaimConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reclaim Task'),
        content: Text('Are you sure you want to reclaim "${widget.task.title}" from your partner?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onReclaim?.call();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Reclaim'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      onLongPressStart: (_) => _handleLongPressStart(),
      onLongPressEnd: (_) => _handleLongPressEnd(),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final scale = _isLongPressing ? 0.9 : _scaleAnimation.value;
          final pulse = _isLongPressing ? 1.0 : _pulseAnimation.value;
          
          return Transform.scale(
            scale: scale * pulse,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Stack(
                children: [
                  // Main bubble
                  Container(
                    width: _getBubbleSize(),
                    height: _getBubbleSize(),
                    decoration: BoxDecoration(
                      color: _getBubbleColor(),
                      borderRadius: BorderRadius.circular(_getBubbleSize() / 2),
                      boxShadow: [
                        BoxShadow(
                          color: _getBubbleColor().withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: widget.task.urgent 
                        ? Border.all(color: Colors.red, width: 3)
                        : null,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Task title
                            Flexible(
                              child: Text(
                                widget.task.title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: _getFontSize(),
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Due date if exists
                            if (widget.task.dueDate != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: widget.task.isOverdue 
                                    ? Colors.red.withOpacity(0.8)
                                    : Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _formatDueDate(widget.task.dueDate!),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Repeatable badge
                  if (widget.task.repeatType != RepeatType.none)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(
                          _getRepeatIcon(),
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  
                  // Long press indicator
                  if (_isLongPressing)
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }



  Color _getBubbleColor() {
    // Base color based on task type and status
    Color baseColor;
    
    // Urgent tasks are always red and don't change with status
    if (widget.task.urgent) {
      return Colors.red;
    }
    
    // Status-based colors (consistent across all task types)
    switch (widget.task.status) {
      case TaskStatus.unclaimed:
        baseColor = widget.tabType == 'shared' ? Colors.purple : Colors.orange;
        break;
      case TaskStatus.claimed:
        baseColor = Colors.blue; // Always blue when claimed
        break;
      case TaskStatus.done:
        baseColor = Colors.green; // Always green when done
        break;
    }
    
    // Overdue tasks override status color
    if (widget.task.dueDate != null && widget.task.isOverdue) {
      return Colors.red.shade600;
    }
    
    return baseColor;
  }

  double _getBubbleSize() {
    // Consistent size to prevent overflow issues
    return 120;
  }

  double _getFontSize() {
    // Consistent font size to prevent overflow
    return 13;
  }



  IconData _getRepeatIcon() {
    switch (widget.task.repeatType) {
      case RepeatType.none:
        return Icons.schedule;
      case RepeatType.daily:
        return Icons.repeat;
      case RepeatType.weekly:
        return Icons.repeat_one;
      case RepeatType.monthly:
        return Icons.repeat_one_on;
      case RepeatType.yearly:
        return Icons.repeat_one_on; // Using available icon
    }
  }

  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;
    
    if (difference < 0) {
      return 'Overdue';
    } else if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference < 7) {
      return '${difference}d';
    } else {
      return '${(difference / 7).round()}w';
    }
  }
}

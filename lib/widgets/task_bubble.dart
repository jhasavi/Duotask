import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/task.dart';
import '../config/theme.dart';
import '../config/constants.dart';

class TaskBubble extends StatefulWidget {
  final Task task;
  final bool isCreatedByPartner;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? claimerInitials;

  const TaskBubble({
    super.key,
    required this.task,
    required this.isCreatedByPartner,
    required this.onTap,
    this.onLongPress,
    this.claimerInitials,
  });

  @override
  State<TaskBubble> createState() => _TaskBubbleState();
}

class _TaskBubbleState extends State<TaskBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppConstants.bubbleAnimationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _getBubbleSize() {
    if (widget.task.priority == TaskPriority.urgent) {
      return AppConstants.bubbleSizeUrgent;
    }

    switch (widget.task.status) {
      case TaskStatus.unclaimed:
        return AppConstants.bubbleSizeUnclaimed;
      case TaskStatus.claimed:
        return AppConstants.bubbleSizeClaimed;
      case TaskStatus.completed:
        return AppConstants.bubbleSizeCompleted;
    }
  }

  Color _getBubbleColor() {
    if (widget.task.status == TaskStatus.completed) {
      return AppTheme.completedColor.withOpacity(0.7);
    }

    if (widget.task.priority == TaskPriority.urgent) {
      return AppTheme.urgentColor;
    }

    return AppTheme.getTaskStatusColor(
      widget.task.status.name,
      isCreatedByPartner: widget.isCreatedByPartner,
    );
  }

  IconData _getStatusIcon() {
    switch (widget.task.status) {
      case TaskStatus.unclaimed:
        return Icons.circle_outlined;
      case TaskStatus.claimed:
        return Icons.access_time;
      case TaskStatus.completed:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = _getBubbleSize();
    final color = _getBubbleColor();

    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: GestureDetector(
          onTap: () {
            // Animate on tap
            _controller.reverse().then((_) {
              _controller.forward();
              widget.onTap();
            });
          },
          onLongPress: widget.onLongPress,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Main content
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getStatusIcon(),
                          color: Colors.white,
                          size: size * 0.25,
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: Text(
                            widget.task.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: size * 0.12,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Claimer initials badge
                if (widget.task.status == TaskStatus.claimed &&
                    widget.claimerInitials != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          widget.claimerInitials!,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Priority indicator
                if (widget.task.priority == TaskPriority.urgent)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.priority_high,
                        color: AppTheme.urgentColor,
                        size: 16,
                      ),
                    ),
                  ),

                // Due date indicator
                if (widget.task.dueDate != null && widget.task.status != TaskStatus.completed)
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _formatDueDate(widget.task.dueDate!),
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now);

    if (difference.inDays == 0) {
      if (difference.inHours > 0) {
        return '${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m';
      } else {
        return 'Now';
      }
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${(difference.inDays / 7).floor()}w';
    }
  }
}

class BubbleField extends CustomPainter {
  final List<Task> tasks;
  final bool Function(Task) isCreatedByPartner;

  BubbleField({
    required this.tasks,
    required this.isCreatedByPartner,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // This could be used for drawing connection lines between bubbles
    // or background decorations
  }

  @override
  bool shouldRepaint(BubbleField oldDelegate) {
    return tasks != oldDelegate.tasks;
  }
}

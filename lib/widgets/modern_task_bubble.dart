import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

/// Modern, simplified task bubble with clean design
class ModernTaskBubble extends StatefulWidget {
  final DuoTask task;
  final String? currentUserId;
  final bool partnerOnline;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onClaim;
  final VoidCallback? onComplete;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;
  final VoidCallback? onOpenChat;
  final VoidCallback? onHandoff;
  final bool handoffPending;

  const ModernTaskBubble({
    super.key,
    required this.task,
    this.currentUserId,
    this.partnerOnline = false,
    this.onTap,
    this.onLongPress,
    this.onClaim,
    this.onComplete,
    this.onDelete,
    this.onRename,
    this.onOpenChat,
    this.onHandoff,
    this.handoffPending = false,
  });

  @override
  State<ModernTaskBubble> createState() => _ModernTaskBubbleState();
}

class _ModernTaskBubbleState extends State<ModernTaskBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
    widget.onTap?.call();
  }

  void _handleLongPress() {
    HapticFeedback.mediumImpact();
    setState(() => _isPressed = true);
    
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _isPressed = false);
    });
    
    widget.onLongPress?.call();
  }

  Color _getBubbleColor() {
    if (widget.task.urgent) {
      return AppTheme.getPriorityColor(true);
    }
    
    switch (widget.task.status) {
      case TaskStatus.unclaimed:
        return Theme.of(context).colorScheme.primaryContainer;
      case TaskStatus.claimed:
        return Theme.of(context).colorScheme.secondaryContainer;
      case TaskStatus.done:
        return Theme.of(context).colorScheme.surfaceVariant;
      default:
        return Theme.of(context).colorScheme.surface;
    }
  }

  double _getBubbleSize() {
    double baseSize = 120.0;
    
    // Adjust size based on status
    switch (widget.task.status) {
      case TaskStatus.unclaimed:
        return baseSize;
      case TaskStatus.claimed:
        return baseSize * 0.9;
      case TaskStatus.done:
        return baseSize * 0.8;
      default:
        return baseSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bubbleSize = _getBubbleSize();
    final hasDueDate = widget.task.dueDate != null;
    final isOverdue = hasDueDate && widget.task.dueDate!.isBefore(DateTime.now());
    final isDueToday = hasDueDate && 
        DateTime(widget.task.dueDate!.year, widget.task.dueDate!.month, widget.task.dueDate!.day) ==
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _isPressed ? _scaleAnimation.value : 1.0,
          child: Opacity(
            opacity: _isPressed ? _fadeAnimation.value : 1.0,
            child: GestureDetector(
              onTap: _handleTap,
              onLongPress: _handleLongPress,
              child: Container(
                width: bubbleSize,
                height: bubbleSize,
                decoration: BoxDecoration(
                  color: _getBubbleColor(),
                  borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
                  border: isOverdue 
                      ? Border.all(color: Colors.red, width: 2)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Main content
                    Padding(
                      padding: const EdgeInsets.all(AppConstants.defaultPadding),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Status indicator
                          if (widget.task.status == TaskStatus.done)
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 24,
                            ),
                          
                          // Task title
                          Flexible(
                            child: Text(
                              widget.task.title,
                              style: AppTheme.bodyStyle.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Due date indicator
                          if (hasDueDate)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isOverdue
                                    ? Colors.red
                                    : isDueToday
                                        ? Colors.orange
                                        : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isOverdue
                                    ? 'Overdue'
                                    : isDueToday
                                        ? 'Today'
                                        : widget.task.dueDateDisplay,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Top-right indicators
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Column(
                        children: [
                          // Urgent indicator
                          if (widget.task.urgent)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          
                          const SizedBox(height: 4),
                          
                          // Repeat indicator
                          if (widget.task.repeatType != RepeatType.none)
                            Icon(
                              Icons.repeat,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                          
                          const SizedBox(height: 4),
                          
                          // Handoff pending indicator
                          if (widget.handoffPending)
                            Icon(
                              Icons.swap_horiz,
                              size: 16,
                              color: Colors.purple,
                            ),
                        ],
                      ),
                    ),
                    
                    // Bottom-left ownership indicator
                    if (widget.task.pairId != null)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: _buildOwnershipIndicator(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOwnershipIndicator() {
    final isMine = widget.currentUserId != null &&
        widget.task.ownerId == widget.currentUserId;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Owner indicator
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isMine ? Colors.blue : Colors.purple,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
        
        const SizedBox(width: 4),
        
        // Partner online indicator
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.partnerOnline ? Colors.green : Colors.grey.shade400,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
          ),
        ),
      ],
    );
  }
}

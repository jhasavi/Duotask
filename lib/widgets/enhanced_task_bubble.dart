import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

/// Enhanced task bubble with modern design and improved UX
class EnhancedTaskBubble extends StatefulWidget {
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
  final bool isSelected;
  final bool showPriority;

  const EnhancedTaskBubble({
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
    this.isSelected = false,
    this.showPriority = true,
  });

  @override
  State<EnhancedTaskBubble> createState() => _EnhancedTaskBubbleState();
}

class _EnhancedTaskBubbleState extends State<EnhancedTaskBubble>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Color?> _borderColorAnimation;
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
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

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _borderColorAnimation = ColorTween(
      begin: Colors.transparent,
      end: Theme.of(context).colorScheme.primary.withOpacity(0.3),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    if (widget.handoffPending) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(EnhancedTaskBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.handoffPending != oldWidget.handoffPending) {
      if (widget.handoffPending) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
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
    final theme = Theme.of(context);
    
    if (widget.task.urgent) {
      return Colors.red.shade50;
    }
    
    switch (widget.task.status) {
      case TaskStatus.unclaimed:
        return theme.colorScheme.primaryContainer;
      case TaskStatus.claimed:
        return theme.colorScheme.secondaryContainer;
      case TaskStatus.done:
        return theme.colorScheme.surfaceVariant;
    }
  }

  Color _getBorderColor() {
    if (widget.isSelected) {
      return Theme.of(context).colorScheme.primary;
    }
    
    if (widget.task.urgent) {
      return Colors.red.shade300;
    }
    
    final hasDueDate = widget.task.dueDate != null;
    final isOverdue = hasDueDate && widget.task.dueDate!.isBefore(DateTime.now());
    
    if (isOverdue) {
      return Colors.red.shade400;
    }
    
    return Colors.transparent;
  }

  double _getBubbleSize() {
    double baseSize = 140.0;
    
    // Adjust size based on status
    switch (widget.task.status) {
      case TaskStatus.unclaimed:
        return baseSize;
      case TaskStatus.claimed:
        return baseSize * 0.9;
      case TaskStatus.done:
        return baseSize * 0.8;
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
      animation: Listenable.merge([_animationController, _pulseController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _isPressed ? _scaleAnimation.value : 
                 widget.handoffPending ? _pulseAnimation.value : 1.0,
          child: Opacity(
            opacity: _isPressed ? _fadeAnimation.value : 1.0,
            child: GestureDetector(
              onTap: _handleTap,
              onLongPress: _handleLongPress,
              child: MouseRegion(
                onEnter: (_) => setState(() => _isHovered = true),
                onExit: (_) => setState(() => _isHovered = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: bubbleSize,
                  height: bubbleSize,
                  decoration: BoxDecoration(
                    color: _getBubbleColor(),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getBorderColor(),
                      width: widget.isSelected ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(_isHovered ? 0.15 : 0.08),
                        blurRadius: _isHovered ? 16 : 12,
                        offset: Offset(0, _isHovered ? 6 : 4),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Main content
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Status indicator
                            if (widget.task.status == TaskStatus.done)
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 28,
                              ),
                            
                            const SizedBox(height: 8),
                            
                            // Task title
                            Flexible(
                              child: Text(
                                widget.task.title,
                                style: AppTheme.bodyStyle.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  height: 1.3,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Due date indicator
                            if (hasDueDate)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isOverdue
                                      ? Colors.red
                                      : isDueToday
                                          ? Colors.orange
                                          : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  isOverdue
                                      ? 'Overdue'
                                      : isDueToday
                                          ? 'Today'
                                          : _formatDueDate(widget.task.dueDate),
                                  style: const TextStyle(
                                    fontSize: 11,
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
                        top: 12,
                        right: 12,
                        child: Column(
                          children: [
                            // Priority indicator
                            if (widget.showPriority && widget.task.urgent)
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.3),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            
                            const SizedBox(height: 6),
                            
                            // Repeat indicator
                            if (widget.task.repeatType != RepeatType.none)
                              Icon(
                                Icons.repeat,
                                size: 18,
                                color: Colors.grey.shade600,
                              ),
                            
                            const SizedBox(height: 6),
                            
                            // Handoff pending indicator
                            if (widget.handoffPending)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.swap_horiz,
                                  size: 16,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      // Bottom-left ownership indicator
                      if (widget.task.pairId != null)
                        Positioned(
                          bottom: 12,
                          left: 12,
                          child: _buildOwnershipIndicator(),
                        ),
                    ],
                  ),
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
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: isMine ? Colors.blue : Colors.purple,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                spreadRadius: 0,
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 6),
        
        // Partner online indicator
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.partnerOnline ? Colors.green : Colors.grey.shade400,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
          ),
        ),
      ],
    );
  }

  String _formatDueDate(DateTime? dueDate) {
    if (dueDate == null) return '';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final taskDate = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (taskDate == today) return 'Today';
    if (taskDate == tomorrow) return 'Tomorrow';

    // Format as "Jan 15" or "Jan 15, 2024" if different year
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = monthNames[dueDate.month - 1];
    final day = dueDate.day;
    final year = dueDate.year;

    if (year == now.year) {
      return '$month $day';
    } else {
      return '$month $day, $year';
    }
  }
}

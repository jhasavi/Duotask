import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task.dart';

class CelebrationService {
  static const _celebrationMessages = [
    "🎉 Task crushed!",
    "✨ Amazing work!",
    "🚀 You're on fire!",
    "💪 Task conquered!",
    "🎯 Bullseye!",
    "⭐ Stellar job!",
    "🏆 Victory achieved!",
    "🎊 Task mastered!",
  ];

  static const _partnerMessages = [
    "Your partner completed a task! 🎉",
    "Teamwork makes the dream work! ✨",
    "Your partner is crushing it! 🚀",
    "Another one bites the dust! 💪",
    "Partner power activated! ⚡",
    "Duo success achieved! 🏆",
  ];

  /// Show celebration for task completion
  static Future<void> showTaskCompletion({
    required BuildContext context,
    required DuoTask task,
    required bool isPartnerTask,
    String? partnerName,
  }) async {
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    final message = isPartnerTask 
        ? _partnerMessages[DateTime.now().millisecond % _partnerMessages.length]
        : _celebrationMessages[DateTime.now().millisecond % _celebrationMessages.length];
    
    // Show celebration overlay
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.3),
        builder: (context) => _CelebrationDialog(
          message: message,
          taskTitle: task.title,
          isPartnerTask: isPartnerTask,
          partnerName: partnerName,
        ),
      );
    }
    
    // Auto-dismiss after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  /// Show quick celebration snackbar
  static void showQuickCelebration({
    required BuildContext context,
    required String message,
    bool isPartnerTask = false,
  }) {
    HapticFeedback.lightImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(
              isPartnerTask ? '👥' : '🎉',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isPartnerTask ? Colors.purple : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

class _CelebrationDialog extends StatefulWidget {
  final String message;
  final String taskTitle;
  final bool isPartnerTask;
  final String? partnerName;

  const _CelebrationDialog({
    required this.message,
    required this.taskTitle,
    required this.isPartnerTask,
    this.partnerName,
  });

  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    // Start animations
    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleController, _fadeController]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: widget.isPartnerTask 
                      ? Colors.purple.withValues(alpha: 0.95)
                      : Colors.green.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Celebration icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isPartnerTask ? Icons.people : Icons.celebration,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Main message
                    Text(
                      widget.message,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    
                    // Task title
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '"${widget.taskTitle}"',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    // Partner info
                    if (widget.isPartnerTask && widget.partnerName != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'by ${widget.partnerName}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

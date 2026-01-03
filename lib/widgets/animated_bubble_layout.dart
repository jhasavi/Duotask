import 'dart:math';
import 'package:flutter/material.dart';
import '../models/task.dart';
import 'task_bubble.dart';

class AnimatedBubbleLayout extends StatefulWidget {
  final List<Task> tasks;
  final bool Function(Task) isCreatedByPartner;
  final Function(Task) onTaskTap;
  final Function(Task) onTaskLongPress;

  const AnimatedBubbleLayout({
    super.key,
    required this.tasks,
    required this.isCreatedByPartner,
    required this.onTaskTap,
    required this.onTaskLongPress,
  });

  @override
  State<AnimatedBubbleLayout> createState() => _AnimatedBubbleLayoutState();
}

class _AnimatedBubbleLayoutState extends State<AnimatedBubbleLayout>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();
  final List<BubblePosition> _bubblePositions = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _initializeBubblePositions();
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedBubbleLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tasks.length != oldWidget.tasks.length ||
        !_tasksEqual(widget.tasks, oldWidget.tasks)) {
      _initializeBubblePositions();
      _controller.forward(from: 0);
    }
  }

  bool _tasksEqual(List<Task> a, List<Task> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _initializeBubblePositions() {
    _bubblePositions.clear();
    
    for (int i = 0; i < widget.tasks.length; i++) {
      bool positionFound = false;
      int attempts = 0;
      const maxAttempts = 50;
      
      while (!positionFound && attempts < maxAttempts) {
        final newPosition = BubblePosition(
          dx: _random.nextDouble(),
          dy: _random.nextDouble(),
          rotation: _random.nextDouble() * 0.2 - 0.1,
        );
        
        // Check if this position overlaps with existing bubbles
        bool overlaps = false;
        for (var existingPos in _bubblePositions) {
          final distance = sqrt(
            pow(newPosition.dx - existingPos.dx, 2) +
            pow(newPosition.dy - existingPos.dy, 2)
          );
          
          // Minimum distance threshold (adjust based on bubble sizes)
          // 0.2 means bubbles need ~20% of container width/height apart
          if (distance < 0.25) {
            overlaps = true;
            break;
          }
        }
        
        if (!overlaps) {
          _bubblePositions.add(newPosition);
          positionFound = true;
        }
        
        attempts++;
      }
      
      // If no position found after max attempts, place it anyway
      if (!positionFound) {
        _bubblePositions.add(BubblePosition(
          dx: _random.nextDouble(),
          dy: _random.nextDouble(),
          rotation: _random.nextDouble() * 0.2 - 0.1,
        ));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              children: List.generate(
                widget.tasks.length,
                (index) {
                  final task = widget.tasks[index];
                  final position = _bubblePositions[index];
                  
                  // Calculate bubble size based on priority
                  double bubbleSize = 120;
                  if (task.priority == TaskPriority.urgent) {
                    bubbleSize = 140;
                  } else if (task.status == TaskStatus.completed) {
                    bubbleSize = 90;
                  } else if (task.status == TaskStatus.claimed) {
                    bubbleSize = 100;
                  }

                  // Calculate position with spacing
                  final padding = bubbleSize / 2 + 16;
                  final maxX = constraints.maxWidth - bubbleSize;
                  final maxY = constraints.maxHeight - bubbleSize;
                  
                  final x = padding + (maxX - padding * 2) * position.dx;
                  final y = padding + (maxY - padding * 2) * position.dy;

                  // Animate entry
                  final curve = Curves.easeOutBack;
                  final animation = CurvedAnimation(
                    parent: _controller,
                    curve: Interval(
                      (index / widget.tasks.length) * 0.3,
                      0.3 + (index / widget.tasks.length) * 0.7,
                      curve: curve,
                    ),
                  );

                  return AnimatedPositioned(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOutCubic,
                    left: x,
                    top: y,
                    child: Transform.scale(
                      scale: animation.value,
                      child: Transform.rotate(
                        angle: position.rotation,
                        child: Opacity(
                          opacity: animation.value,
                          child: SizedBox(
                            width: bubbleSize,
                            height: bubbleSize,
                            child: TaskBubble(
                              task: task,
                              isCreatedByPartner: widget.isCreatedByPartner(task),
                              onTap: () => widget.onTaskTap(task),
                              onLongPress: () => widget.onTaskLongPress(task),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class BubblePosition {
  final double dx;
  final double dy;
  final double rotation;

  BubblePosition({
    required this.dx,
    required this.dy,
    required this.rotation,
  });
}

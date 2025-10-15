import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VoiceFriendlyFAB extends StatefulWidget {
  final VoidCallback? onPressed;
  final String? tooltip;
  final IconData icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double size;

  const VoiceFriendlyFAB({
    super.key,
    this.onPressed,
    this.tooltip,
    this.icon = Icons.add,
    this.backgroundColor,
    this.foregroundColor,
    this.size = 72, // Larger than standard FAB for voice accessibility
  });

  @override
  State<VoiceFriendlyFAB> createState() => _VoiceFriendlyFABState();
}

class _VoiceFriendlyFABState extends State<VoiceFriendlyFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
    
    // Haptic feedback for tactile response
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.backgroundColor ?? colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: (widget.backgroundColor ?? colorScheme.primary).withOpacity(0.3),
                  blurRadius: _isPressed ? 8 : 12,
                  offset: Offset(0, _isPressed ? 2 : 4),
                  spreadRadius: _isPressed ? 1 : 2,
                ),
              ],
              // Add border for better contrast
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTapDown: _handleTapDown,
                onTapUp: _handleTapUp,
                onTapCancel: _handleTapCancel,
                onTap: widget.onPressed,
                borderRadius: BorderRadius.circular(widget.size / 2),
                child: Center(
                  child: Icon(
                    widget.icon,
                    color: widget.foregroundColor ?? Colors.white,
                    size: widget.size * 0.4, // Proportional icon size
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Voice-friendly speed dial for quick actions
class VoiceFriendlySpeedDial extends StatefulWidget {
  final List<SpeedDialChild> children;
  final IconData? icon;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const VoiceFriendlySpeedDial({
    super.key,
    required this.children,
    this.icon,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<VoiceFriendlySpeedDial> createState() => _VoiceFriendlySpeedDialState();
}

class _VoiceFriendlySpeedDialState extends State<VoiceFriendlySpeedDial>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125, // 45 degrees
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
    
    // Haptic feedback
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Speed dial children
        if (_isOpen) ...[
          ...widget.children.asMap().entries.map((entry) {
            final index = entry.key;
            final child = entry.value;
            
            return AnimatedBuilder(
              animation: _animationController,
              builder: (context, childWidget) {
                final delay = index * 0.1;
                final animation = Tween<double>(
                  begin: 0.0,
                  end: 1.0,
                ).animate(CurvedAnimation(
                  parent: _animationController,
                  curve: Interval(delay, delay + 0.3, curve: Curves.easeOut),
                ));
                
                return Transform.scale(
                  scale: animation.value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - animation.value) * 20),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: child,
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ],
        
        // Main FAB
        AnimatedBuilder(
          animation: _rotationAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationAnimation.value * 2 * 3.14159,
              child: VoiceFriendlyFAB(
                onPressed: _toggle,
                icon: widget.icon ?? Icons.add,
                tooltip: widget.tooltip,
                backgroundColor: widget.backgroundColor,
                foregroundColor: widget.foregroundColor,
              ),
            );
          },
        ),
      ],
    );
  }
}

// Speed dial child widget
class SpeedDialChild extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const SpeedDialChild({
    super.key,
    required this.child,
    this.onPressed,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onPressed?.call();
        HapticFeedback.lightImpact();
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor ?? Theme.of(context).colorScheme.secondary,
          boxShadow: [
            BoxShadow(
              color: (backgroundColor ?? Theme.of(context).colorScheme.secondary).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Center(child: child),
      ),
    );
  }
}

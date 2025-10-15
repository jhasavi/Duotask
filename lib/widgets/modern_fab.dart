import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

/// Modern floating action button with improved design
class ModernFAB extends StatefulWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool isLoading;
  final bool isExtended;
  final String? label;

  const ModernFAB({
    super.key,
    this.onPressed,
    this.icon = Icons.add,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.isLoading = false,
    this.isExtended = false,
    this.label,
  });

  @override
  State<ModernFAB> createState() => _ModernFABState();
}

class _ModernFABState extends State<ModernFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
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

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125,
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
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: FloatingActionButton(
              onPressed: widget.isLoading ? null : widget.onPressed,
              backgroundColor: widget.backgroundColor ?? colorScheme.primary,
              foregroundColor: widget.foregroundColor ?? colorScheme.onPrimary,
              elevation: widget.elevation ?? 6,
              tooltip: widget.tooltip,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: widget.isExtended
                  ? _buildExtendedContent()
                  : _buildIconContent(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIconContent() {
    if (widget.isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return Icon(
      widget.icon,
      size: 24,
    );
  }

  Widget _buildExtendedContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isLoading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        else
          Icon(widget.icon, size: 20),
        const SizedBox(width: 8),
        Text(
          widget.label ?? 'Add',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Modern speed dial FAB
class ModernSpeedDialFAB extends StatefulWidget {
  final List<SpeedDialChild> children;
  final IconData icon;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isOpen;

  const ModernSpeedDialFAB({
    super.key,
    required this.children,
    this.icon = Icons.add,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.isOpen = false,
  });

  @override
  State<ModernSpeedDialFAB> createState() => _ModernSpeedDialFABState();
}

class _ModernSpeedDialFABState extends State<ModernSpeedDialFAB>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(ModernSpeedDialFAB oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Speed dial children
        ...widget.children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;
          final delay = index * 0.1;
          
          return AnimatedPositioned(
            duration: Duration(milliseconds: 300 + (index * 50)),
            curve: Curves.easeOutCubic,
            bottom: widget.isOpen ? 80.0 + (index * 60.0) : 16.0,
            right: 16.0,
            child: AnimatedOpacity(
              duration: Duration(milliseconds: 200 + (index * 50)),
              opacity: widget.isOpen ? 1.0 : 0.0,
              child: AnimatedScale(
                duration: Duration(milliseconds: 200 + (index * 50)),
                scale: widget.isOpen ? 1.0 : 0.0,
                child: FloatingActionButton.small(
                  onPressed: child.onPressed,
                  backgroundColor: child.backgroundColor,
                  foregroundColor: child.foregroundColor,
                  tooltip: child.tooltip,
                  child: child.icon,
                ),
              ),
            ),
          );
        }).toList(),
        
        // Main FAB
        Positioned(
          bottom: 16.0,
          right: 16.0,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: ModernFAB(
                    onPressed: () {
                      // Toggle speed dial
                    },
                    icon: widget.icon,
                    tooltip: widget.tooltip,
                    backgroundColor: widget.backgroundColor,
                    foregroundColor: widget.foregroundColor,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Speed dial child item
class SpeedDialChild {
  final VoidCallback? onPressed;
  final Widget icon;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const SpeedDialChild({
    this.onPressed,
    required this.icon,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
  });
}

/// Modern mini FAB
class ModernMiniFAB extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isLoading;

  const ModernMiniFAB({
    super.key,
    this.onPressed,
    required this.icon,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FloatingActionButton.small(
      onPressed: isLoading ? null : onPressed,
      backgroundColor: backgroundColor ?? colorScheme.secondaryContainer,
      foregroundColor: foregroundColor ?? colorScheme.onSecondaryContainer,
      tooltip: tooltip,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
          : Icon(icon, size: 18),
    );
  }
}

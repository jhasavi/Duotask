import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

class ContextualHelpTooltip extends StatefulWidget {
  final String tooltipId;
  final String message;
  final Widget child;
  final bool showOnce;
  final Duration? autoHideDuration;

  const ContextualHelpTooltip({
    super.key,
    required this.tooltipId,
    required this.message,
    required this.child,
    this.showOnce = true,
    this.autoHideDuration,
  });

  @override
  State<ContextualHelpTooltip> createState() => _ContextualHelpTooltipState();
}

class _ContextualHelpTooltipState extends State<ContextualHelpTooltip>
    with TickerProviderStateMixin {
  bool _showTooltip = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _checkTooltipStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _autoHideTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkTooltipStatus() async {
    if (!widget.showOnce) {
      _showTooltip = true;
      _startAnimation();
      return;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool('tooltip_${widget.tooltipId}') ?? false;
    
    if (!hasShown && mounted) {
      setState(() {
        _showTooltip = true;
      });
      _startAnimation();
      
      // Mark as shown
      await prefs.setBool('tooltip_${widget.tooltipId}', true);
    }
  }

  void _startAnimation() {
    _animationController.forward();
    
    if (widget.autoHideDuration != null) {
      _autoHideTimer = Timer(widget.autoHideDuration!, () {
        _hideTooltip();
      });
    }
  }

  void _hideTooltip() {
    _autoHideTimer?.cancel();
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showTooltip = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showTooltip)
          Positioned.fill(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildTooltipOverlay(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTooltipOverlay() {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Semi-transparent overlay
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideTooltip,
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
          ),
          
          // Tooltip content
          Positioned(
            top: 100,
            left: 16,
            right: 16,
            child: _buildTooltipContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTooltipContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Arrow pointing down
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 0,
              height: 0,
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.transparent, width: 8),
                  right: BorderSide(color: Colors.transparent, width: 8),
                  bottom: BorderSide(color: Colors.transparent, width: 8),
                ),
              ),
              child: Transform.translate(
                offset: const Offset(0, -8),
                child: Container(
                  width: 0,
                  height: 0,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: Theme.of(context).colorScheme.surface,
                        width: 8,
                      ),
                      right: BorderSide(
                        color: Theme.of(context).colorScheme.surface,
                        width: 8,
                      ),
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.surface,
                        width: 8,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Message
          Text(
            widget.message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),
          
          // Action button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _hideTooltip,
                child: const Text('Got it'),
              ),
              if (!widget.showOnce) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('tooltip_${widget.tooltipId}', true);
                    _hideTooltip();
                  },
                  child: const Text('Don\'t show again'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// Helper widget for showing contextual help icons
class HelpIcon extends StatelessWidget {
  final String tooltipId;
  final String message;
  final IconData icon;
  final double size;
  final Color? color;

  const HelpIcon({
    super.key,
    required this.tooltipId,
    required this.message,
    this.icon = Icons.help_outline,
    this.size = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ContextualHelpTooltip(
      tooltipId: tooltipId,
      message: message,
      child: Icon(
        icon,
        size: size,
        color: color ?? Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

// Helper widget for showing contextual help on buttons
class HelpButton extends StatelessWidget {
  final String tooltipId;
  final String message;
  final Widget child;
  final VoidCallback? onPressed;

  const HelpButton({
    super.key,
    required this.tooltipId,
    required this.message,
    required this.child,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ContextualHelpTooltip(
      tooltipId: tooltipId,
      message: message,
      child: ElevatedButton(
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}

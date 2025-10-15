import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

class QuickActionTutorial extends StatefulWidget {
  final VoidCallback? onDismiss;
  final VoidCallback? onAddTask;

  const QuickActionTutorial({
    super.key,
    this.onDismiss,
    this.onAddTask,
  });

  @override
  State<QuickActionTutorial> createState() => _QuickActionTutorialState();
}

class _QuickActionTutorialState extends State<QuickActionTutorial>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  int _currentStep = 0;
  final List<TutorialStep> _steps = [
    TutorialStep(
      title: 'Create Your First Task',
      description: 'Tap the + button to add a new task',
      icon: Icons.add,
      action: 'Tap +',
    ),
    TutorialStep(
      title: 'Add Task Details',
      description: 'Enter a title and set a due date if needed',
      icon: Icons.edit,
      action: 'Fill in details',
    ),
    TutorialStep(
      title: 'Save and Share',
      description: 'Your task will appear in the list and sync with your partner',
      icon: Icons.check,
      action: 'Save task',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
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
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      _completeTutorial();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _skipTutorial() {
    _completeTutorial();
  }

  Future<void> _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('quick_tutorial_completed', true);
    
    if (!mounted) return;
    
    await _animationController.reverse();
    
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    }
  }

  void _startCreatingTask() {
    _completeTutorial();
    if (widget.onAddTask != null) {
      widget.onAddTask!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.lightbulb_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Quick Start Guide',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _skipTutorial,
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Step content
              _buildStepContent(),
              
              const SizedBox(height: 20),
              
              // Navigation
              _buildNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    final step = _steps[_currentStep];
    
    return Column(
      children: [
        // Step indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _steps.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentStep == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentStep == index
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Step icon
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Icon(
            step.icon,
            size: 30,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Step title
        Text(
          step.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 8),
        
        // Step description
        Text(
          step.description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 16),
        
        // Action button
        if (_currentStep == 0)
          ElevatedButton.icon(
            onPressed: _startCreatingTask,
            icon: const Icon(Icons.add),
            label: Text(step.action),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildNavigation() {
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: _previousStep,
              child: const Text('Previous'),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _currentStep == _steps.length - 1 ? _completeTutorial : _nextStep,
            child: Text(_currentStep == _steps.length - 1 ? 'Got it!' : 'Next'),
          ),
        ),
      ],
    );
  }
}

class TutorialStep {
  final String title;
  final String description;
  final IconData icon;
  final String action;

  TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.action,
  });
}

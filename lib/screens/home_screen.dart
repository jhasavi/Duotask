import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../services/auth_service.dart';
import '../services/task_service.dart';
import '../services/pairing_service.dart';
import '../models/task.dart';
import '../widgets/offline_banner.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/animated_bubble_layout.dart';
import '../widgets/task_creation_dialog.dart';
import '../widgets/daily_checkin_banner.dart';
import '../widgets/weekly_summary_modal.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../utils/haptic_helper.dart';
import 'pairing_screen.dart';
import 'task_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _confettiController = ConfettiController(
    duration: AppConstants.confettiDuration,
  );
  final _taskInputController = TextEditingController();
  int _selectedTab = 0; // 0=Personal, 1=Paired
  TaskVisibility? _visibilityFilter; // null=All, personal, group

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to avoid calling setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _taskInputController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authService = context.read<AuthService>();
    final taskService = context.read<TaskService>();
    final pairingService = context.read<PairingService>();

    final userId = authService.currentUser?.id;
    if (userId != null) {
      await Future.wait([
        taskService.loadTasks(userId),
        pairingService.checkPairingStatus(userId),
      ]);

      // Show weekly summary if it's time and user is paired
      if (pairingService.isPaired && pairingService.partner != null) {
        _checkAndShowWeeklySummary(userId, pairingService);
      }
    }
  }

  Future<void> _checkAndShowWeeklySummary(
    String userId,
    PairingService pairingService,
  ) async {
    // Check if it's Sunday and we haven't shown this week
    final now = DateTime.now();
    if (now.weekday != DateTime.sunday) return;
    if (now.hour < 9) return; // Only show after 9am

    final shouldShow = await WeeklySummaryModal.shouldShow();
    if (!shouldShow) return;

    final taskService = context.read<TaskService>();
    final authService = context.read<AuthService>();
    
    // Get weekly completion counts
    final counts = await taskService.getWeeklyCompletions(
      userId,
      pairingService.partner?.id,
    );

    if (!mounted) return;

    // Show modal
    await showDialog(
      context: context,
      builder: (context) => WeeklySummaryModal(
        userName: authService.currentUser?.displayName ?? 'You',
        partnerName: pairingService.partner?.displayName ?? 'Partner',
        userCompletedCount: counts['user'] ?? 0,
        partnerCompletedCount: counts['partner'] ?? 0,
      ),
    );

    // Mark as shown
    await WeeklySummaryModal.markAsShown();
  }

  Future<void> _handleTaskTap(Task task) async {
    // Provide immediate haptic feedback
    await HapticHelper.mediumImpact();
    
    final authService = context.read<AuthService>();
    final taskService = context.read<TaskService>();
    final userId = authService.currentUser?.id;

    if (userId == null) return;

    // Cycle task status
    final success = await taskService.cycleTaskStatus(task, userId);

    if (success && task.status == TaskStatus.claimed) {
      // Show confetti when task is completed (going from claimed to completed)
      _confettiController.play();
      
      // Success haptic feedback
      await HapticHelper.success();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppConstants.successTaskCompleted),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _showTaskDetail(Task task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(task: task),
      ),
    );
  }

  Future<void> _createTask() async {
    final input = _taskInputController.text.trim();
    if (input.isEmpty) return;

    // Light haptic feedback for task creation
    await HapticHelper.lightImpact();

    final authService = context.read<AuthService>();
    final taskService = context.read<TaskService>();
    final pairingService = context.read<PairingService>();
    
    final userId = authService.currentUser?.id;
    if (userId == null) return;

    // Parse natural language input
    final parsed = taskService.parseNaturalInput(input);

    // Determine visibility - if paired and no filter, create as personal
    TaskVisibility visibility = TaskVisibility.personal;
    String? pairId;
    
    if (pairingService.isPaired && pairingService.currentPairing != null) {
      // If user has set a visibility filter, default to that for new tasks
      visibility = _visibilityFilter ?? TaskVisibility.personal;
      if (visibility == TaskVisibility.group) {
        pairId = pairingService.currentPairing!.id;
      }
    }

    final task = await taskService.createTask(
      title: parsed['title'] as String,
      userId: userId,
      priority: parsed['priority'] as TaskPriority,
      dueDate: parsed['dueDate'] as DateTime?,
      assignedToId: pairingService.partner?.id,
      visibility: visibility,
      pairId: pairId,
    );

    if (task != null) {
      _taskInputController.clear();
      // Success haptic
      await HapticHelper.lightImpact();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              visibility == TaskVisibility.group
                  ? 'Group task created!'
                  : AppConstants.successTaskCreated,
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      // Error haptic
      await HapticHelper.error();
    }
  }

  Future<void> _showCreateTaskDialog() async {
    final pairingService = context.read<PairingService>();
    final authService = context.read<AuthService>();
    final taskService = context.read<TaskService>();
    
    final userId = authService.currentUser?.id;
    if (userId == null) return;

    await HapticHelper.lightImpact();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => TaskCreationDialog(
        isPaired: pairingService.isPaired,
        pairId: pairingService.currentPairing?.id,
        onCreateTask: (title, visibility, {priority = TaskPriority.normal, recurrence = TaskRecurrence.none}) async {
          // Parse natural language input
          final parsed = taskService.parseNaturalInput(title);

          String? pairId;
          if (visibility == TaskVisibility.group && pairingService.currentPairing != null) {
            pairId = pairingService.currentPairing!.id;
          }

          final task = await taskService.createTask(
            title: parsed['title'] as String,
            userId: userId,
            priority: priority, // Use dialog selection, not parsed
            recurrence: recurrence,
            dueDate: parsed['dueDate'] as DateTime?,
            assignedToId: pairingService.partner?.id,
            visibility: visibility,
            pairId: pairId,
          );

          if (task != null) {
            await HapticHelper.success();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    visibility == TaskVisibility.group
                        ? 'Group task created!'
                        : AppConstants.successTaskCreated,
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          } else {
            await HapticHelper.error();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          // Pairing status
          Consumer<PairingService>(
            builder: (context, pairingService, child) {
              if (pairingService.isPaired && pairingService.partner != null) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Chip(
                    avatar: CircleAvatar(
                      backgroundImage: pairingService.partner!.avatarUrl != null
                          ? NetworkImage(pairingService.partner!.avatarUrl!)
                          : null,
                      child: pairingService.partner!.avatarUrl == null
                          ? Text(
                              pairingService.partner!.displayName?[0] ?? 'P',
                            )
                          : null,
                    ),
                    label: Text(
                      pairingService.partner!.displayName ?? 'Partner',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onDeleted: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PairingScreen(),
                        ),
                      );
                    },
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.person_add),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PairingScreen(),
                    ),
                  );
                },
              );
            },
          ),
          
          // Settings
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Offline banner
              const OfflineBanner(),
              
              // Pairing prompt banner (if not paired)
              Consumer<PairingService>(
                builder: (context, pairingService, child) {
                  if (!pairingService.isPaired) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.1),
                            AppTheme.secondaryColor.withOpacity(0.1),
                          ],
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.people,
                            color: AppTheme.primaryColor,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '👥 Pair up to start sharing tasks!',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Connect with your partner to collaborate',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const PairingScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.link),
                            label: const Text('Pair Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Quick add task bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _taskInputController,
                        decoration: const InputDecoration(
                          hintText: 'Add task (e.g., "Grocery @6pm")',
                          prefixIcon: Icon(Icons.add_circle_outline),
                        ),
                        onSubmitted: (_) => _createTask(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _createTask,
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Tab selector
              Consumer<PairingService>(
                builder: (context, pairingService, child) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SegmentedButton<int>(
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        visualDensity: VisualDensity.standard,
                      ),
                      segments: [
                        const ButtonSegment(
                          value: 0,
                          label: Text('Personal'),
                          icon: Icon(Icons.person),
                        ),
                        ButtonSegment(
                          value: 1,
                          label: Text(pairingService.isPaired ? 'Paired' : 'Shared'),
                          icon: const Icon(Icons.people),
                        ),
                      ],
                      selected: {_selectedTab},
                      onSelectionChanged: (Set<int> newSelection) {
                        setState(() {
                          _selectedTab = newSelection.first;
                        });
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Task bubbles
              Expanded(
                child: Consumer<TaskService>(
                  builder: (context, taskService, child) {
                    // Show shimmer loading while tasks are being loaded
                    if (taskService.isLoading && taskService.tasks.isEmpty) {
                      return const TaskListShimmer(itemCount: 3);
                    }

                    final authService = context.read<AuthService>();
                    final currentUserId = authService.currentUser?.id;

                    List<Task> filteredTasks;
                    
                    // Filter by tab (Personal vs Paired)
                    if (_selectedTab == 0) {
                      // Personal tab - show only personal tasks (exclude old completed)
                      final twelveHoursAgo = DateTime.now().subtract(const Duration(hours: 12));
                      filteredTasks = taskService.tasks
                          .where((t) => 
                            t.visibility == TaskVisibility.personal &&
                            (t.status != TaskStatus.completed || 
                              (t.completedAt != null && t.completedAt!.isAfter(twelveHoursAgo)))
                          )
                          .toList();
                    } else {
                      // Paired tab - show only group tasks (exclude old completed)
                      final twelveHoursAgo = DateTime.now().subtract(const Duration(hours: 12));
                      filteredTasks = taskService.tasks
                          .where((t) => 
                            t.visibility == TaskVisibility.group &&
                            (t.status != TaskStatus.completed || 
                              (t.completedAt != null && t.completedAt!.isAfter(twelveHoursAgo)))
                          )
                          .toList();
                    }

                    return Column(
                      children: [
                        // Daily Check-In Banner
                        DailyCheckInBanner(
                          onFocusMode: () {
                            // Switch to Paired tab
                            setState(() {
                              _selectedTab = 1;
                            });
                          },
                        ),

                        // Task List
                        Expanded(
                          child: filteredTasks.isEmpty
                              ? _buildEmptyState()
                              : AnimatedBubbleLayout(
                                  tasks: filteredTasks,
                                  isCreatedByPartner: (task) =>
                                      task.createdById != currentUserId,
                                  onTaskTap: _handleTaskTap,
                                  onTaskLongPress: _showTaskDetail,
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),

          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 3.14 / 2, // Down
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              colors: const [
                AppTheme.primaryColor,
                AppTheme.secondaryColor,
                AppTheme.accentColor,
                AppTheme.completedColor,
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTaskDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
        tooltip: 'Create new task',
      ),
    );
  }

  Widget _buildEmptyState() {
    String emptyTitle;
    String emptyMessage;
    IconData emptyIcon;

    switch (_selectedTab) {
      case 1: // Paired
        emptyTitle = 'No shared tasks yet';
        emptyMessage =
            'Tasks marked as "Group" will appear here.\nCreate a shared task to get started! 👥';
        emptyIcon = Icons.people_outline;
        break;
      default: // Personal
        emptyTitle = 'No personal tasks yet';
        emptyMessage =
            'Start by adding your first task above.\nTry: "Buy groceries @6pm" 🛒';
        emptyIcon = Icons.person_outline;
    }

    return EmptyStateWidget(
      icon: emptyIcon,
      title: emptyTitle,
      message: emptyMessage,
      iconSize: 100,
    );
  }
}

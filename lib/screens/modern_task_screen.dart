import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/task_manager_service.dart';
import '../services/celebration_service.dart';
import '../services/smart_suggestions_service.dart';
import '../widgets/enhanced_task_bubble.dart';
import '../widgets/modern_dashboard.dart';
import '../widgets/smart_task_form.dart';
import '../widgets/task_chat_sheet.dart';
import '../widgets/enhanced_task_card.dart';
import '../widgets/task_dialog.dart';
import '../widgets/pairing_status_card.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/error_dialog.dart';
import '../widgets/empty_state_guidance.dart';
import '../widgets/quick_action_tutorial.dart';
import '../widgets/pairing_promotion_card.dart';
import '../widgets/contextual_help_tooltip.dart';
import '../widgets/quick_invite_button.dart';
import '../widgets/task_bubble.dart';
import '../widgets/frequent_partners_list.dart';
import '../widgets/task_comments_widget.dart';
import '../widgets/color_tutorial_widget.dart';
import '../utils/logger.dart';
import '../utils/enhanced_theme.dart';
import 'pairing_screen.dart';
import 'auth_screen.dart';
import '../services/app_dependencies.dart';
import '../services/analytics_service.dart';

class ModernTaskScreen extends StatefulWidget {
  final bool isPaired;
  final bool embedded;
  final String? partnerNameFromParent;
  final VoidCallback? onPairStatusChanged;
  final VoidCallback? onOpenPairTab;
  final bool disableRealtime;
  final TaskService? taskServiceOverride;

  const ModernTaskScreen({
    super.key,
    required this.isPaired,
    this.embedded = false,
    this.partnerNameFromParent,
    this.onPairStatusChanged,
    this.onOpenPairTab,
    this.disableRealtime = false,
    this.taskServiceOverride,
  });

  @override
  State<ModernTaskScreen> createState() => _ModernTaskScreenState();
}

class _ModernTaskScreenState extends State<ModernTaskScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late ConfettiController _confettiController;
  final SmartSuggestionsService _suggestionsService = SmartSuggestionsService();
  
  bool _isLoading = false;
  String? _error;
  String? _friendlyMessage;
  bool _showFriendlyMessage = false;
  Timer? _messageTimer;
  
  // Tab data
  List<DuoTask> _personalTasks = [];
  List<DuoTask> _sharedTasks = [];
  List<DuoTask> _partnerTasks = [];
  Map<String, bool> _handoffPendingMap = {};
  bool _partnerOnline = false;
  String? _partnerName;
  
  // Realtime subscription
  RealtimeChannel? _tasksSubscription;
  RealtimeChannel? _pairingSubscription;
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  
  // Guidance state
  bool _showQuickTutorial = false;
  bool _showPairingPromotion = false;
  bool _showColorTutorial = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // 4 tabs now including Settings
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    
    // Load data after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTasks();
      _loadPartnerInfo();
      _checkGuidanceState();
      _setupRealtimeSubscription();
      _setupPairingSubscription();
      
      // Set default tab based on pairing status - use a small delay to ensure proper initialization
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          if (widget.isPaired) {
            _tabController.animateTo(0); // Shared tab
          } else {
            _tabController.animateTo(1); // Personal tab if not paired
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _confettiController.dispose();
    _messageTimer?.cancel();
    _searchController.dispose();
    _disposeRealtimeSubscription();
    _disposePairingSubscription();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      final deps = AppDependencies.of(context);
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('No user found, cannot load tasks');
        return;
      }

      print('Loading tasks for user: ${user.id}');
      final allTasks = await deps.tasks.getTasks(userId: user.id);
      print('Total tasks loaded: ${allTasks.length}');
      
      if (!mounted) return;
      
      setState(() {
        // Personal tasks: tasks with scope 'personal' or no scope, owned by user
        _personalTasks = allTasks.where((t) => 
          t.ownerId == user.id && 
          (t.pairId == null || t.pairId!.isEmpty)
        ).toList();
        
        // Shared tasks: tasks with scope 'shared' and pair_id, owned by user
        _sharedTasks = allTasks.where((t) => 
          t.ownerId == user.id && 
          t.pairId != null && 
          t.pairId!.isNotEmpty
        ).toList();
        
        // Partner tasks: tasks owned by partner that are shared with this user
        _partnerTasks = allTasks.where((t) => 
          t.ownerId != user.id && 
          t.pairId != null && 
          t.pairId!.isNotEmpty
        ).toList();
        
        print('Task categorization for user ${user.id}:');
        print('- Personal: ${_personalTasks.length}');
        print('- Shared: ${_sharedTasks.length}');
        print('- Partner: ${_partnerTasks.length}');
        
        // Debug: Print all tasks with their categorization
        for (var task in allTasks) {
          final isPersonal = task.ownerId == user.id && task.pairId == null;
          final isShared = task.ownerId == user.id && task.pairId != null;
          final isPartner = task.ownerId != user.id && task.pairId == user.id;
          
          print('Task: ${task.title} | Owner: ${task.ownerId} | Pair: ${task.pairId} | Type: ${isPersonal ? "Personal" : isShared ? "Shared" : isPartner ? "Partner" : "Other"}');
        }
        
        print('Task categorization:');
        print('- Personal: ${_personalTasks.length}');
        print('- Shared: ${_sharedTasks.length}');
        print('- Partner: ${_partnerTasks.length}');
        
        // Print task details for debugging
        for (var task in allTasks) {
          print('Task: ${task.title} | Owner: ${task.ownerId} | Pair: ${task.pairId} | Claimed: ${task.claimedBy}');
        }
      });
    } catch (e) {
      print('Error loading tasks: $e');
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupRealtimeSubscription() {
    if (widget.disableRealtime) return;
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Subscribe to task changes for the current user and their partner
      _tasksSubscription = Supabase.instance.client
          .channel('tasks_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'tasks',
            callback: (payload) {
              print('Realtime task update received: $payload');
              
              // Always refresh tasks when any change occurs
              // This ensures both partners see updates immediately
              print('Task change detected, refreshing UI...');
              _refreshUIOnTaskChange();
            },
          )
          .subscribe();

      print('✅ Realtime subscription set up for tasks');
    } catch (e) {
      print('❌ Failed to set up realtime subscription: $e');
    }
  }

  void _disposeRealtimeSubscription() {
    try {
      _tasksSubscription?.unsubscribe();
      _tasksSubscription = null;
      print('✅ Realtime subscription disposed');
    } catch (e) {
      print('❌ Error disposing realtime subscription: $e');
    }
  }

  void _setupPairingSubscription() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final deps = AppDependencies.of(context);
    _pairingSubscription = deps.pairing.listenToPairingStatus(
      user.id,
      (userData) {
        // Handle pairing status changes
        if (mounted) {
          setState(() {
            // Refresh pairing status and partner info
            _loadPartnerInfo();
          });
        }
      },
    );
  }

  void _disposePairingSubscription() {
    try {
      _pairingSubscription?.unsubscribe();
      _pairingSubscription = null;
      print('✅ Pairing subscription disposed');
    } catch (e) {
      print('❌ Error disposing pairing subscription: $e');
    }
  }

  /// Refresh the UI when tasks change (called from realtime updates)
  void _refreshUIOnTaskChange() {
    if (mounted) {
      print('🔄 Refreshing UI due to task change...');
      _loadTasks();
      _loadPartnerInfo();
    }
  }

  /// Filter tasks based on search query
  List<DuoTask> _filterTasks(List<DuoTask> tasks) {
    if (_searchQuery.isEmpty) return tasks;
    
    final query = _searchQuery.toLowerCase();
    return tasks.where((task) {
      return task.title.toLowerCase().contains(query) ||
             task.status.name.toLowerCase().contains(query) ||
             (task.dueDate != null && 
              task.dueDate!.toString().toLowerCase().contains(query)) ||
             (task.urgent && 'urgent'.contains(query)) ||
             (task.repeatType != RepeatType.none && 
              task.repeatType.name.toLowerCase().contains(query));
    }).toList();
  }

  /// Get filtered tasks for current tab
  List<DuoTask> _getFilteredTasksForCurrentTab() {
    final currentTasks = _getCurrentTasks();
    return _filterTasks(currentTasks);
  }

  Future<void> _loadPartnerInfo() async {
    try {
      final deps = AppDependencies.of(context);
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('No current user for partner info');
        return;
      }

      print('Loading partner info for user: ${user.id}');
      
      // Load partner information using new clean pairing service
      final pairInfo = await deps.pairing.getCurrentPair();
      if (pairInfo != null) {
        setState(() {
          _partnerName = pairInfo['partner_name'] ?? 'Partner';
          _partnerOnline = true; // If we have a pair, partner is considered online
        });
        print('✅ Partner info loaded: $_partnerName (online: $_partnerOnline)');
        
        // Notify parent that pairing status has changed
        widget.onPairStatusChanged?.call();
      } else {
        print('❌ No current pair found - user may not be paired');
        setState(() {
          _partnerName = null;
          _partnerOnline = false;
        });
        
        // Notify parent that pairing status has changed
        widget.onPairStatusChanged?.call();
      }
    } catch (e) {
      Log.warn('Failed to load partner info: $e');
      print('❌ Error loading partner info: $e');
      setState(() {
        _partnerName = null;
        _partnerOnline = false;
      });
      
      // Notify parent that pairing status has changed
      widget.onPairStatusChanged?.call();
    }
  }

  Future<void> _checkGuidanceState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasShownTutorial = prefs.getBool('quick_tutorial_completed') ?? false;
      final hasShownPairingPromotion = prefs.getBool('pairing_promotion_shown') ?? false;
      final hasShownColorTutorial = prefs.getBool('color_tutorial_shown') ?? false;
      
      if (!hasShownTutorial && mounted) {
        setState(() {
          _showQuickTutorial = true;
        });
      }
      
      if (!hasShownPairingPromotion && !widget.isPaired && mounted) {
        setState(() {
          _showPairingPromotion = true;
        });
      }
      
      if (!hasShownColorTutorial && mounted) {
        setState(() {
          _showColorTutorial = true;
        });
      }
    } catch (e) {
      Log.warn('Error checking guidance state: $e');
    }
  }

  void _openPairingScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PairingScreen(),
      ),
    );
  }

  Future<void> _unpair() async {
    try {
      final deps = AppDependencies.of(context);

      await deps.pairing.unpair();
      
      // Refresh the UI
      await _loadPartnerInfo();
      await _loadTasks();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully unpaired')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unpair: $e')),
        );
      }
    }
  }

  Future<void> _showAddTaskDialog() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SmartTaskForm(
        onSubmit: _createTask,
        onCancel: () => Navigator.of(context).pop(),
        tabType: _getCurrentTabType(),
        isPaired: widget.isPaired,
        partnerName: _partnerName,
      ),
    );
  }

  String _getCurrentTabType() {
    switch (_tabController.index) {
      case 0:
        return 'shared';
      case 1:
        return 'personal';
      case 2:
        return 'partner';
      default:
        return 'personal';
    }
  }

  Future<void> _createTask(String title, DateTime? dueDate, bool urgent, RepeatType repeatType) async {
    try {
      final deps = AppDependencies.of(context);
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Determine if this should be a shared task based on current tab
      String? pairId;
      if (_tabController.index == 0 && widget.isPaired) {
        // If we're on the shared tab and paired, make it a shared task
        try {
          final pairInfo = await deps.pairing.getCurrentPair();
          pairId = pairInfo?['pair_id'];
          print('Creating shared task with pair ID: $pairId');
        } catch (e) {
          print('Error getting current pair info: $e');
          // Continue with personal task if pair info fails
        }
      } else {
        print('Creating personal task (tab: ${_tabController.index})');
      }

      final task = DuoTask(
        id: const Uuid().v4(),
        title: title,
        status: TaskStatus.unclaimed,
        ownerId: user.id,
        pairId: pairId, // This will be null for personal tasks, partner ID for shared tasks
        repeatType: repeatType,
        dueDate: dueDate,
        urgent: urgent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      print('Creating task: ${task.title} | Pair ID: ${task.pairId} | Tab: ${_tabController.index}');
      await deps.tasks.createTask(task);
      
      // Track for suggestions
      _suggestionsService.trackTaskCreated(user.id, task);
      
      // Update task lists
      await _loadTasks();
      
      if (!mounted) return;
      Navigator.of(context).pop();
      
      _showSuccessMessage('Task created successfully!');
    } catch (e) {
      print('Error creating task: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create task: $e')),
      );
    }
  }

  Future<void> _claimTask(DuoTask task) async {
    try {
      final deps = AppDependencies.of(context);
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await deps.tasks.claimTask(task.id, user.id);
      await _loadTasks();
      
      _showSuccessMessage('Task claimed!');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to claim task: $e')),
      );
    }
  }

  Future<void> _completeTask(DuoTask task) async {
    try {
      final deps = AppDependencies.of(context);
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await deps.tasks.completeTask(task.id, user.id);
      await _loadTasks();
      
      _showSuccessMessage('Task completed! 🎉');
      _confettiController.play();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete task: $e')),
      );
    }
  }

  Future<void> _cycleTaskStatus(DuoTask task) async {
    try {
      final deps = AppDependencies.of(context);
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Determine next status based on current status and task type
      TaskStatus nextStatus;
      final isShared = task.pairId != null;
      
      if (isShared) {
        // Shared tasks: Unclaimed → Claimed → Done → Unclaimed
        switch (task.status) {
          case TaskStatus.unclaimed:
            nextStatus = TaskStatus.claimed;
            break;
          case TaskStatus.claimed:
            nextStatus = TaskStatus.done;
            break;
          case TaskStatus.done:
            nextStatus = TaskStatus.unclaimed;
            break;
        }
      } else {
        // Personal tasks: Unclaimed → Done → Unclaimed (skip claimed)
        switch (task.status) {
          case TaskStatus.unclaimed:
            nextStatus = TaskStatus.done;
            break;
          case TaskStatus.claimed:
            nextStatus = TaskStatus.done;
            break;
          case TaskStatus.done:
            nextStatus = TaskStatus.unclaimed;
            break;
        }
      }

      // Update task status
      await deps.tasks.updateTaskStatus(task.id, nextStatus);
      
      // Update the task in the UI immediately for better responsiveness
      setState(() {
        final updatedTask = task.copyWith(
          status: nextStatus,
          claimedBy: nextStatus == TaskStatus.claimed ? user.id : null,
          updatedAt: DateTime.now(),
        );
        
        // Update in the appropriate list
        if (task.pairId != null) {
          // Shared task
          final index = _sharedTasks.indexWhere((t) => t.id == task.id);
          if (index != -1) {
            _sharedTasks[index] = updatedTask;
          }
          // Also update in partner tasks if it exists there
          final partnerIndex = _partnerTasks.indexWhere((t) => t.id == task.id);
          if (partnerIndex != -1) {
            _partnerTasks[partnerIndex] = updatedTask;
          }
        } else {
          // Personal task
          final index = _personalTasks.indexWhere((t) => t.id == task.id);
          if (index != -1) {
            _personalTasks[index] = updatedTask;
          }
        }
      });
      
      // Also refresh from server to ensure consistency
      _loadTasks();
      
      // Show success message with toast notification
      String message;
      switch (nextStatus) {
        case TaskStatus.unclaimed:
          message = 'Task reset to unclaimed';
          break;
        case TaskStatus.claimed:
          message = 'Task claimed!';
          break;
        case TaskStatus.done:
          message = 'Task completed! 🎉';
          _confettiController.play();
          break;
      }
      
      _showToastMessage(message);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update task status: $e')),
      );
    }
  }

  Future<void> _reclaimTask(DuoTask task) async {
    try {
      final deps = AppDependencies.of(context);
      final success = await deps.pairing.reclaimTask(task.id);
      
      if (success) {
        await _loadTasks();
        _showToastMessage('Task reclaimed! 🔄');
      } else {
        throw Exception('Failed to reclaim task');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reclaim task: $e')),
      );
    }
  }

  Future<void> _toggleTaskUrgent(DuoTask task) async {
    try {
      final deps = AppDependencies.of(context);
      await deps.tasks.toggleTaskUrgent(task.id);
      await _loadTasks();
      
      _showSuccessMessage(
        task.urgent ? 'Task marked as urgent!' : 'Task urgency removed'
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to toggle task urgency: $e')),
      );
    }
  }

  Future<void> _deleteTask(DuoTask task) async {
    try {
      final deps = AppDependencies.of(context);
      await deps.tasks.deleteTask(task.id);
      await _loadTasks();
      
      _showSuccessMessage('Task deleted');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete task: $e')),
      );
    }
  }

  Future<void> _openComments(DuoTask task) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: TaskCommentsWidget(
          taskId: task.id,
          taskTitle: task.title,
        ),
      ),
    );
  }

  void _showUnpairDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpair with Partner?'),
        content: Text(
          'This will end your pairing with ${_partnerName ?? 'your partner'}. '
          'Both of you will lose access to shared tasks. '
          'Your partner will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _unpairWithPartner();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );
  }

  Future<void> _unpairWithPartner() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final deps = AppDependencies.of(context);
      final success = await deps.pairing.unpair();
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully unpaired with ${_partnerName ?? 'partner'}'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh the UI
        _loadPartnerInfo();
        _loadTasks();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to unpair. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openChat(DuoTask task) async {
    if (task.pairId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pair first to chat about a task')),
      );
      return;
    }
    
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TaskChatSheet(task: task),
    );
  }

  void _showSuccessMessage(String message) {
    setState(() {
      _friendlyMessage = message;
      _showFriendlyMessage = true;
    });

    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showFriendlyMessage = false);
      }
    });
  }

  List<DuoTask> _getCurrentTasks() {
    switch (_tabController.index) {
      case 0: // Shared tab
        // For shared tasks, combine tasks from both partners
        // This ensures both partners see the same shared tasks
        final allSharedTasks = <DuoTask>[];
        
        // Add user's shared tasks
        allSharedTasks.addAll(_sharedTasks);
        
        // Add partner's shared tasks (if paired)
        if (widget.isPaired && _partnerTasks.isNotEmpty) {
          allSharedTasks.addAll(_partnerTasks);
        }
        
        // Remove duplicates based on task ID
        final uniqueTasks = <String, DuoTask>{};
        for (final task in allSharedTasks) {
          uniqueTasks[task.id] = task;
        }
        
        return uniqueTasks.values.toList();
        
      case 1: // Personal tab
        // Personal tasks are only for the current user
        return _personalTasks;
        
      default:
        return [];
    }
  }

  String _getCurrentTabTitle() {
    switch (_tabController.index) {
      case 0:
        return 'Shared'; // All shared tasks from both partners
      case 1:
        return 'Personal'; // Only my personal tasks
      case 2:
        return widget.isPaired ? (_partnerName ?? 'Partner') : 'Partner'; // Partner's tasks only
      default:
        return 'Personal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = Stack(
      children: [
        // Main content based on bottom navigation
        IndexedStack(
          index: _tabController.index,
          children: [
            _buildTaskTab(_getCurrentTasks(), 'shared'),
            _buildTaskTab(_personalTasks, 'personal'),
            _buildPairingTab(),
            _buildSettingsTab(),
          ],
        ),
        
        // Confetti overlay
        if (!widget.disableRealtime)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: pi / 2,
                maxBlastForce: 5,
                minBlastForce: 2,
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.1,
                colors: const [
                  Colors.pink,
                  Colors.purple,
                  Colors.blue,
                  Colors.green,
                  Colors.yellow,
                  Colors.orange,
                  Colors.red,
                ],
              ),
            ),
          ),
        
        // Success message
        if (_showFriendlyMessage)
          Positioned(
            top: 100,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(EnhancedTheme.radius16),
                border: Border.all(color: Colors.green.shade300),
                boxShadow: EnhancedTheme.shadowMedium,
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _friendlyMessage!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Floating action button
        if (!widget.embedded)
          Positioned(
            right: 20,
            bottom: 20,
            child: ContextualHelpTooltip(
              tooltipId: 'add_task_button',
              message: 'Tap here to create a new task. You can add personal tasks or shared tasks with your partner.',
              child: FloatingActionButton.extended(
                onPressed: _showAddTaskDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Task'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
          
        // Quick action tutorial overlay
        if (_showQuickTutorial)
          Positioned.fill(
            child: QuickActionTutorial(
              onDismiss: () {
                setState(() {
                  _showQuickTutorial = false;
                });
              },
              onAddTask: () {
                setState(() {
                  _showQuickTutorial = false;
                });
                _showAddTaskDialog();
              },
            ),
          ),
          
        // Pairing promotion overlay
        if (_showPairingPromotion)
          Positioned.fill(
            child: PairingPromotionCard(
              onPairWithSomeone: () {
                setState(() {
                  _showPairingPromotion = false;
                });
                _openPairingScreen();
              },
              onDismiss: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('pairing_promotion_shown', true);
                setState(() {
                  _showPairingPromotion = false;
                });
              },
            ),
          ),
          
        // Color tutorial overlay
        if (_showColorTutorial)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ColorTutorialWidget(
                    onDismiss: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('color_tutorial_shown', true);
                      setState(() {
                        _showColorTutorial = false;
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (widget.embedded) return bodyContent;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: _isSearching 
          ? _buildSearchField()
          : Text(_getAppBarTitle()),
        actions: [
          // Search button
          IconButton(
            tooltip: 'Search tasks',
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          // Help button
          HelpIcon(
            tooltipId: 'app_help',
            message: 'Welcome to DuoTask! Use the tabs below to switch between shared, personal, and partner tasks. Tap the + button to create new tasks.',
          ),
          // Pair status indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(
                  widget.isPaired ? Icons.favorite : Icons.person_off,
                  color: widget.isPaired ? Colors.pink : Colors.grey,
                ),
                const SizedBox(width: 6),
                if (!widget.isPaired)
                  const Text('Unpaired')
                else if (_partnerName != null && _partnerName!.isNotEmpty)
                  Text('Paired with $_partnerName')
                else
                  const Text('Paired'),
              ],
            ),
          ),
          // Quick add task button
          IconButton(
            tooltip: 'Add task',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showAddTaskDialog,
          ),
          // Sign out button
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: bodyContent,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _tabController.index,
        onTap: (index) {
          if (index != _tabController.index) {
            setState(() {
              _tabController.animateTo(index);
            });
            // Refresh tasks when switching tabs
            Future.delayed(const Duration(milliseconds: 50), () {
              if (mounted) {
                _loadTasks();
              }
            });
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Shared',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Personal',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.link),
            label: 'Pair',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }



  Widget _buildPairingTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current pairing status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.isPaired ? Icons.favorite : Icons.favorite_border,
                        color: widget.isPaired ? Colors.purple : Colors.grey,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.isPaired ? 'Currently Paired' : 'Not Paired',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: widget.isPaired ? Colors.purple : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  if (widget.isPaired && _partnerName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Paired with: $_partnerName',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _unpair,
                      icon: const Icon(Icons.link_off),
                      label: const Text('Unpair'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _openPairingScreen,
                      icon: const Icon(Icons.link),
                      label: const Text('Pair with Someone'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Frequent partners section
          const Text(
            'Frequent Partners',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Quick re-pair with previous partners',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          
          // Frequent partners list
          SizedBox(
            height: 300, // Fixed height to prevent overflow
            child: FrequentPartnersList(
              onPartnerSelected: () {
                // Refresh pairing status after selection
                _loadPartnerInfo();
              },
              onPairingStatusChanged: () {
                // Refresh the entire screen
                setState(() {
                  _loadPartnerInfo();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerStatusCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.isPaired ? Icons.favorite : Icons.person_off,
                  color: widget.isPaired ? Colors.pink : Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isPaired ? 'Paired' : 'Not Paired',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.isPaired && _partnerName != null)
                        Text(
                          'with $_partnerName',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.isPaired)
                  Icon(
                    _partnerOnline ? Icons.circle : Icons.circle_outlined,
                    color: _partnerOnline ? Colors.green : Colors.grey,
                    size: 16,
                  ),
              ],
            ),
            if (widget.isPaired) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openPairingScreen,
                      icon: const Icon(Icons.edit),
                      label: const Text('Manage Pairing'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddTaskDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Shared Task'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(DuoTask task, String tabType) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          task.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: ${task.status.name}',
              style: TextStyle(
                color: task.status == TaskStatus.done 
                  ? Colors.green.shade700
                  : task.status == TaskStatus.claimed 
                  ? Colors.orange.shade700
                  : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (task.dueDate != null)
              Text(
                'Due: ${task.dueDate!.toString().split(' ')[0]}',
                style: TextStyle(
                  color: task.isOverdue ? Colors.red.shade700 : Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.urgent)
              const Icon(Icons.priority_high, color: Colors.red),
            if (task.dueDate != null)
              Icon(
                Icons.schedule,
                color: task.isOverdue ? Colors.red : Colors.grey,
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'complete':
                    _completeTask(task);
                    break;
                  case 'delete':
                    _deleteTask(task);
                    break;
                  case 'claim':
                    if (tabType == 'shared' || tabType == 'partner') {
                      _claimTask(task);
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
                if (task.status != TaskStatus.done)
                  const PopupMenuItem(
                    value: 'complete',
                    child: Text('Complete'),
                  ),
                if ((tabType == 'shared' || tabType == 'partner') && task.status == TaskStatus.unclaimed)
                  const PopupMenuItem(
                    value: 'claim',
                    child: Text('Claim'),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          // Handle task tap
        },
        onLongPress: () {
          // Handle task long press
        },
      ),
    );
  }

  Widget _buildTaskTab(List<DuoTask> tasks, String tabType) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Get filtered tasks for current tab
    final filteredTasks = _getFilteredTasksForCurrentTab();

    if (filteredTasks.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        // Show search results empty state
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No tasks found for "$_searchQuery"',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try a different search term',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        );
      } else {
        // Show regular empty state
        return EmptyStateGuidance(
          tabType: tabType,
          isPaired: widget.isPaired,
          partnerName: _partnerName,
          onPairWithSomeone: _openPairingScreen,
        );
      }
    }

    // Use task bubbles in a grid layout with enhanced refresh
    return RefreshIndicator(
      onRefresh: () async {
        await _loadTasks();
        await _loadPartnerInfo();
      },
      child: Column(
        children: [
          // Search results indicator
          if (_searchQuery.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Icon(Icons.search, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    '${filteredTasks.length} task${filteredTasks.length == 1 ? '' : 's'} found for "$_searchQuery"',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          // Tasks grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.0,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: filteredTasks.length,
              itemBuilder: (context, index) {
                final task = filteredTasks[index];
                return TaskBubble(
                  key: ValueKey('${task.id}_${task.status}_${task.claimedBy}'), // Force rebuild on status change
                  task: task,
                  tabType: tabType,
                  onTap: () => _showTaskOptions(task),
                  onLongPress: () => _showTaskOptions(task),
                  onStatusChange: () => _cycleTaskStatus(task),
                  onDelete: () => _deleteTask(task),
                  onToggleUrgent: () => _toggleTaskUrgent(task),
                  onReclaim: () => _reclaimTask(task),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(EnhancedTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: EnhancedTheme.spacing24),
          
          // User Info
          Card(
            child: ListTile(
              leading: const Icon(Icons.person, color: Colors.blue),
              title: const Text(
                'User Profile',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                Supabase.instance.client.auth.currentUser?.email ?? '',
                style: const TextStyle(color: Colors.black54),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                // TODO: Navigate to user profile
              },
            ),
          ),
          
          const SizedBox(height: EnhancedTheme.spacing16),
          
          // Pairing Status
          Card(
            child: ListTile(
              leading: Icon(
                widget.isPaired ? Icons.favorite : Icons.person_off,
                color: widget.isPaired ? Colors.pink : Colors.grey,
              ),
              title: Text(
                widget.isPaired ? 'Paired' : 'Not Paired',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: widget.isPaired 
                ? Text(
                    'Partner: ${_partnerName ?? 'Unknown'}',
                    style: const TextStyle(color: Colors.black54),
                  )
                : const Text(
                    'Pair with someone to share tasks',
                    style: const TextStyle(color: Colors.black54),
                  ),
              trailing: widget.isPaired 
                ? IconButton(
                    icon: const Icon(Icons.link_off, color: Colors.red),
                    onPressed: () => _showUnpairDialog(),
                  )
                : const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                if (!widget.isPaired) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PairingScreen(),
                    ),
                  );
                }
              },
            ),
          ),
          
          const SizedBox(height: EnhancedTheme.spacing16),
          
          // App Info
          Card(
            child: ListTile(
              leading: const Icon(Icons.info, color: Colors.blue),
              title: const Text(
                'About',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'DuoTask v1.0.0',
                style: TextStyle(color: Colors.black54),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                // TODO: Show about dialog
              },
            ),
          ),
          
          const SizedBox(height: EnhancedTheme.spacing16),
          
          // Notifications
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications, color: Colors.orange),
              title: const Text(
                'Notifications',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Manage notification preferences',
                style: TextStyle(color: Colors.black54),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                // TODO: Navigate to notifications settings
              },
            ),
          ),
          
          const SizedBox(height: EnhancedTheme.spacing16),
          
          // Privacy & Security
          Card(
            child: ListTile(
              leading: const Icon(Icons.security, color: Colors.green),
              title: const Text(
                'Privacy & Security',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Manage your privacy settings',
                style: TextStyle(color: Colors.black54),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                // TODO: Navigate to privacy settings
              },
            ),
          ),
          
          const SizedBox(height: EnhancedTheme.spacing16),
          
          // Color Guide
          Card(
            child: ListTile(
              leading: const Icon(Icons.color_lens, color: Colors.purple),
              title: const Text(
                'Task Colors Guide',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Learn what each color means',
                style: TextStyle(color: Colors.black54),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                setState(() {
                  _showColorTutorial = true;
                });
              },
            ),
          ),
          
          const SizedBox(height: EnhancedTheme.spacing32),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showAddTaskDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String tabType) {
    String message;
    String subtitle;
    IconData icon;
    Color color;

    switch (tabType) {
      case 'personal':
        message = 'No personal tasks yet';
        subtitle = 'Create your first personal task to get started';
        icon = Icons.person_outline;
        color = Colors.blue;
        break;
      case 'shared':
        message = 'No shared tasks yet';
        subtitle = 'Create tasks to share with your partner';
        icon = Icons.share_outlined;
        color = Colors.purple;
        break;
      case 'partner':
        if (widget.isPaired) {
          message = 'No tasks from ${_partnerName ?? 'partner'}';
          subtitle = 'Your partner hasn\'t created any tasks yet';
          icon = Icons.people_outline;
          color = Colors.green;
        } else {
          message = 'Not paired yet';
          subtitle = 'Pair with someone to see their tasks';
          icon = Icons.link_off;
          color = Colors.grey;
        }
        break;
      default:
        message = 'No tasks yet';
        subtitle = 'Create your first task to get started';
        icon = Icons.task_alt_outlined;
        color = Colors.blue;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(EnhancedTheme.spacing32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 60,
                color: color,
              ),
            ),
            const SizedBox(height: EnhancedTheme.spacing24),
            Text(
              message,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: EnhancedTheme.spacing8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: EnhancedTheme.spacing32),
            if (tabType != 'partner' || widget.isPaired)
              ElevatedButton.icon(
                onPressed: _showAddTaskDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Task'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: EnhancedTheme.spacing24,
                    vertical: EnhancedTheme.spacing12,
                  ),
                ),
              ),
            if (tabType == 'partner' && !widget.isPaired)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PairingScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.link),
                label: const Text('Pair with Someone'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: EnhancedTheme.spacing24,
                    vertical: EnhancedTheme.spacing12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showTaskOptions(DuoTask task) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(EnhancedTheme.spacing16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Task'),
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Implement edit task
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Comments'),
              subtitle: const Text('View and add comments'),
              onTap: () {
                Navigator.of(context).pop();
                _openComments(task);
              },
            ),
            if (task.pairId != null)
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Open Chat'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openChat(task);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Task', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(context).pop();
                _deleteTask(task);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search tasks...',
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.grey[400]),
      ),
      style: const TextStyle(color: Colors.black87),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  String _getAppBarTitle() {
    switch (_tabController.index) {
      case 0:
        return widget.isPaired ? 'Shared Tasks' : 'Pair to get started';
      case 1:
        return 'Personal Tasks';
      case 2:
        return 'Pair';
      case 3:
        return 'Settings';
      default:
        return 'DuoTask';
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => AuthScreen()),
      );
    } catch (e) {
      Log.error('Sign out failed: $e');
    }
  }

  void _showToastMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getToastIcon(message),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _getToastColor(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  IconData _getToastIcon(String message) {
    if (message.contains('claimed')) {
      return Icons.person_add;
    } else if (message.contains('completed') || message.contains('done')) {
      return Icons.check_circle;
    } else if (message.contains('reclaimed')) {
      return Icons.swap_horiz;
    } else if (message.contains('unclaimed')) {
      return Icons.radio_button_unchecked;
    }
    return Icons.info;
  }

  Color _getToastColor(String message) {
    if (message.contains('claimed')) {
      return Colors.orange;
    } else if (message.contains('completed') || message.contains('done')) {
      return Colors.green;
    } else if (message.contains('reclaimed')) {
      return Colors.blue;
    } else if (message.contains('unclaimed')) {
      return Colors.grey;
    }
    return Colors.blue;
  }
}

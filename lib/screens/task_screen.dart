import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../services/task_service.dart';
import '../services/auth_service.dart';
import 'pairing_screen.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> with TickerProviderStateMixin {
  final TaskService _taskService = TaskService();
  final AuthService _authService = AuthService();
  
  late TabController _tabController;
  List<Task> _personalTasks = [];
  List<Task> _pairedTasks = [];
  bool _isLoading = true;
  String? _errorMessage;
  AppUser? _currentUser;
  String? _partnerId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserAndTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndTasks() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      final user = _authService.currentUser;
      if (user != null) {
        // Load user profile
        final userProfile = await _loadUserProfile(user.id);
        if (mounted) {
          setState(() {
            _currentUser = userProfile;
            _partnerId = userProfile?.pairedWith;
          });
        }

        // Load tasks
        await _loadTasks();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<AppUser?> _loadUserProfile(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('usr')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      if (response != null) {
        return AppUser.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Error loading user profile: $e');
      return null;
    }
  }

  Future<void> _loadTasks() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final personalTasks = await _taskService.getPersonalTasks(user.id);
        final pairedTasks = await _taskService.getPairedTasks(user.id, _partnerId);
        
        if (mounted) {
      setState(() {
            _personalTasks = personalTasks;
            _pairedTasks = pairedTasks;
        _isLoading = false;
      });
        }
      }
    } catch (e) {
      if (mounted) {
      setState(() {
          _errorMessage = e.toString();
        _isLoading = false;
      });
      }
    }
  }

  Future<void> _createTask() async {
    final result = await showDialog<Task>(
      context: context,
      builder: (context) => CreateTaskDialog(
        onTaskCreated: () => _loadTasks(),
      ),
    );

    if (result != null) {
      await _loadTasks();
    }
  }

  Future<void> _claimTask(Task task) async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        await _taskService.claimTask(task.id, user.id);
        await _loadTasks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task claimed! 🎯'),
              backgroundColor: Color(0xFF3B82F6),
            ),
          );
        }
        }
      } catch (e) {
      print('Error claiming task: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
            content: Text('Failed to claim task: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _cycleTaskStatus(Task task) async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        if (task.status == 'unclaimed') {
          // Unclaimed -> Claimed
          await _taskService.claimTask(task.id, user.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Task claimed! 🎯'),
                backgroundColor: Color(0xFF3B82F6),
              ),
            );
          }
        } else if (task.status == 'claimed') {
          // Claimed -> Done
          await _taskService.completeTask(task.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Task completed! ✅'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          }
        } else if (task.status == 'done') {
          // Done -> Unclaimed (reset)
          await _taskService.updateTask(task.id, {
            'status': 'unclaimed',
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Task reset to unclaimed! 🔄'),
                backgroundColor: Color(0xFFF59E0B),
              ),
            );
          }
        }
        
        await _loadTasks();
      }
    } catch (e) {
      print('Error cycling task status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update task: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _completeTask(Task task) async {
    try {
      await _taskService.completeTask(task.id);
      await _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task completed! ✅'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete task: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _editTask(Task task) async {
    final result = await showDialog<Task>(
      context: context,
      builder: (context) => EditTaskDialog(task: task),
    );

    if (result != null) {
      await _loadTasks();
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _taskService.deleteTask(task.id);
        await _loadTasks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task deleted! 🗑️'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete task: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  void _navigateToPairing() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PairingScreen()),
    ).then((_) => _loadUserAndTasks());
  }

  Future<void> _unpairFromPartner() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpair from Partner'),
        content: const Text('Are you sure you want to unpair from your partner? This will disconnect you from shared tasks.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _authService.unpairFromPartner();
        await _loadUserAndTasks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unpaired from partner! 👋'),
              backgroundColor: Color(0xFFF59E0B),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to unpair: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF667EEA),
                    const Color(0xFF764BA2),
                  ],
                ),
              ),
              child: const Icon(
                Icons.task_alt,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'DuoTask',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        actions: [
          if (_currentUser?.pairedWith == null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF1F5F9),
              ),
              child: IconButton(
                onPressed: _navigateToPairing,
                icon: const Icon(
                  Icons.people_outline,
                  color: Color(0xFF64748B),
                ),
                tooltip: 'Pair with partner',
              ),
            ),
          if (_currentUser?.pairedWith != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF1F5F9),
              ),
              child: IconButton(
                onPressed: _unpairFromPartner,
                icon: const Icon(
                  Icons.person_remove,
                  color: Color(0xFF64748B),
                ),
                tooltip: 'Unpair',
              ),
            ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFFEF2F2),
            ),
            child: IconButton(
              onPressed: () async {
                await _authService.signOut();
              },
              icon: const Icon(
                Icons.logout,
                color: Color(0xFFDC2626),
              ),
              tooltip: 'Sign out',
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFFF1F5F9),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF64748B),
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF667EEA),
                    const Color(0xFF764BA2),
                  ],
                ),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Personal'),
                Tab(text: 'Shared'),
                Tab(text: 'All'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF8FAFC),
                    Color(0xFFF1F5F9),
                  ],
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading your tasks...',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _errorMessage != null
              ? Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFF8FAFC),
                        Color(0xFFF1F5F9),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: const Color(0xFFFEF2F2),
                          ),
                          child: const Icon(
                            Icons.error_outline,
                            color: Color(0xFFDC2626),
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Oops! Something went wrong',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadUserAndTasks,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTaskList(_personalTasks, 'personal'),
                    _buildTaskList(_pairedTasks, 'shared'),
                    _buildTaskList([..._personalTasks, ..._pairedTasks], 'all'),
                  ],
                ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF667EEA),
              const Color(0xFF764BA2),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667EEA).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _createTask,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList(List<Task> tasks, String type) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: const Color(0xFFF1F5F9),
              ),
              child: Icon(
                type == 'personal' ? Icons.person_outline : Icons.people_outline,
                color: const Color(0xFF94A3B8),
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              type == 'personal' ? 'No personal tasks yet' : 'No shared tasks yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              type == 'personal' 
                  ? 'Create your first personal task to get started!'
                  : 'Share tasks with your partner to collaborate!',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF8FAFC),
            Color(0xFFF1F5F9),
          ],
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return _buildTaskCard(task);
        },
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    // Determine task status colors and styling
    Color statusColor;
    Color backgroundColor;
    IconData statusIcon;
    String statusText;
    double opacity = 1.0;
    double scale = 1.0;

    switch (task.status) {
      case 'unclaimed':
        statusColor = const Color(0xFFF59E0B);
        backgroundColor = Colors.white;
        statusIcon = Icons.radio_button_unchecked;
        statusText = 'Unclaimed';
        break;
      case 'claimed':
        statusColor = const Color(0xFF3B82F6);
        backgroundColor = const Color(0xFFF8FAFC);
        statusIcon = Icons.radio_button_checked;
        statusText = 'Claimed';
        opacity = 0.95;
        scale = 0.98;
        break;
      case 'done':
        statusColor = const Color(0xFF10B981);
        backgroundColor = const Color(0xFFF0FDF4);
        statusIcon = Icons.check_circle;
        statusText = 'Done';
        opacity = 0.8;
        scale = 0.95;
        break;
      default:
        statusColor = const Color(0xFF6B7280);
        backgroundColor = Colors.white;
        statusIcon = Icons.help_outline;
        statusText = 'Unknown';
    }

    // Check if this is a shared task
    final isShared = task.pairId != null;

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: backgroundColor,
            border: Border.all(
              color: statusColor.withOpacity(0.12),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 24,
                offset: const Offset(0, 6),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: statusColor.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => _cycleTaskStatus(task),
              splashColor: statusColor.withOpacity(0.1),
              highlightColor: statusColor.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with status and actions
                    Row(
                      children: [
                        // Status indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: statusColor.withOpacity(0.1),
                            border: Border.all(
                              color: statusColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                statusIcon,
                                color: statusColor,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        
                        // Shared indicator
                        if (isShared)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: const Color(0xFF667EEA).withOpacity(0.1),
                              border: Border.all(
                                color: const Color(0xFF667EEA).withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.people,
                                  color: Color(0xFF667EEA),
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Shared',
                                  style: TextStyle(
                                    color: const Color(0xFF667EEA),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Task title
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        height: 1.3,
                      ),
                    ),
                    
                    // Task description (if available)
                    if (task.description != null && task.description!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        task.description!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF64748B),
                          height: 1.5,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Footer with actions
                    Row(
                      children: [
                        // Task owner/claimer info
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: const Color(0xFFF1F5F9),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              task.status == 'claimed' 
                                  ? 'Claimed by ${task.ownerId}'
                                  : 'Created by ${task.ownerId}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 14),
                        
                        // Click hint
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: statusColor.withOpacity(0.1),
                            border: Border.all(
                              color: statusColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Tap to cycle',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        
                        // Edit button (for task owner)
                        if (task.ownerId == _authService.currentUser?.id) ...[
                          const SizedBox(width: 10),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: const Color(0xFFF59E0B).withOpacity(0.1),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: IconButton(
                              onPressed: () => _editTask(task),
                              icon: const Icon(
                                Icons.edit,
                                color: Color(0xFFF59E0B),
                                size: 18,
                              ),
                              tooltip: 'Edit task',
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 10),
                          
                          // Delete button (for task owner)
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: const Color(0xFFDC2626).withOpacity(0.1),
                              border: Border.all(
                                color: const Color(0xFFDC2626).withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: IconButton(
                              onPressed: () => _deleteTask(task),
                              icon: const Icon(
                                Icons.delete,
                                color: Color(0xFFDC2626),
                                size: 18,
                              ),
                              tooltip: 'Delete task',
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CreateTaskDialog extends StatefulWidget {
  final VoidCallback? onTaskCreated;
  
  const CreateTaskDialog({super.key, this.onTaskCreated});

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isShared = false;
  final TaskService _taskService = TaskService();
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createTask() async {
    if (_formKey.currentState!.validate()) {
      try {
        final user = _authService.currentUser;
        if (user != null) {
          // Get current user profile to check if paired
          final userProfile = await Supabase.instance.client
              .from('usr')
              .select()
              .eq('id', user.id)
              .maybeSingle();
          
          String? partnerId;
          if (_isShared && userProfile != null) {
            partnerId = userProfile['paired_with'];
            if (partnerId == null) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please pair with a partner first to create shared tasks'),
                    backgroundColor: Color(0xFFF59E0B),
                  ),
                );
              }
              return;
            }
          }

          await _taskService.createTask(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
            userId: user.id,
            partnerId: partnerId,
          );

          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Task created successfully! 🎉'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
            widget.onTaskCreated?.call(); // Call the callback to refresh the list
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create task: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Create New Task',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextFormField(
              controller: _titleController,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1E293B),
                ),
              decoration: const InputDecoration(
                labelText: 'Task Title',
                  labelStyle: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return 'Please enter a task title';
                }
                return null;
              },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextFormField(
              controller: _descriptionController,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1E293B),
                ),
              decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  labelStyle: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
              ),
              maxLines: 3,
            ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF1F5F9),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: const Color(0xFF667EEA).withOpacity(0.1),
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Color(0xFF667EEA),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Share with partner',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const Text(
                          'Make this task visible to your partner',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isShared,
              onChanged: (value) {
                      if (mounted) {
                setState(() {
                          _isShared = value;
                        });
                      }
                    },
                    activeColor: const Color(0xFF667EEA),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF667EEA),
                const Color(0xFF764BA2),
              ],
            ),
          ),
          child: ElevatedButton(
            onPressed: _createTask,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Create Task',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
} 

class EditTaskDialog extends StatefulWidget {
  final Task task;
  
  const EditTaskDialog({super.key, required this.task});

  @override
  State<EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<EditTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final TaskService _taskService = TaskService();

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.task.title;
    _descriptionController.text = widget.task.description ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateTask() async {
            if (_formKey.currentState!.validate()) {
      try {
        await _taskService.updateTask(widget.task.id, {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        });

        if (mounted) {
          Navigator.of(context).pop(widget.task);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task updated successfully! ✏️'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update task: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Edit Task',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextFormField(
                controller: _titleController,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1E293B),
                ),
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  labelStyle: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'Please enter a task title';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextFormField(
                controller: _descriptionController,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1E293B),
                ),
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  labelStyle: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                maxLines: 3,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF667EEA),
                const Color(0xFF764BA2),
              ],
            ),
          ),
          child: ElevatedButton(
            onPressed: _updateTask,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Update Task',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
} 
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
import '../widgets/task_bubble.dart';
import '../widgets/task_list_widget.dart';
import '../widgets/task_filters_widget.dart';
import '../widgets/task_search_bar.dart';
import '../widgets/task_chat_sheet.dart';
import '../utils/logger.dart';
import 'pairing_screen.dart';
import '../services/app_dependencies.dart';
import '../services/analytics_service.dart';
import '../services/task_service.dart';
import '../services/celebration_service.dart';
import '../widgets/task_chat_sheet.dart';

class TaskScreen extends StatefulWidget {
  final bool isPaired;
  final bool embedded; // render content only when true (no Scaffold)
  final String?
      partnerNameFromParent; // fallback to show immediate paired message
  final VoidCallback? onPairStatusChanged;
  final VoidCallback? onOpenPairTab;
  // Testability: allow disabling realtime wiring and overriding TaskService
  final bool disableRealtime;
  final TaskService? taskServiceOverride;
  // Optional: override filter and UI for tabbed Me/You/Ours usage
  final String? forcedFilter; // 'all' | 'mine' | 'partner'
  final bool hideFilterChips; // hide filter chips when using tabs
  final bool todayOnly; // show only today's tasks (and optionally overdue)
  const TaskScreen({
    super.key,
    required this.isPaired,
    this.embedded = false,
    this.partnerNameFromParent,
    this.onPairStatusChanged,
    this.onOpenPairTab,
    this.disableRealtime = false,
    this.taskServiceOverride,
    this.forcedFilter,
    this.hideFilterChips = false,
    this.todayOnly = false,
  });

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  bool _isLoading = false; // Track loading state for async actions

  // Show error banner if _error is set
  Widget _buildErrorBanner() {
    if (_error == null) return const SizedBox.shrink();
    return MaterialBanner(
      content: Text(_error!, style: const TextStyle(color: Colors.white)),
      backgroundColor: Colors.red,
      actions: [
        TextButton(
          onPressed: () => setState(() => _error = null),
          child: const Text('DISMISS', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
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
      builder: (ctx) {
        return TaskChatSheet(task: task);
      },
    );
  }



  Future<void> _loadAddDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final r = prefs.getString(_addRepeatKey);
      final u = prefs.getBool(_addUrgentKey);
      if (!mounted) return;
      setState(() {
        if (r != null) {
          final match = RepeatType.values.firstWhere(
            (e) => e.name == r,
            orElse: () => RepeatType.none,
          );
          _repeatType = match;
        }
        _addUrgent = u ?? false;
      });
    } catch (_) {}
  }

  Future<void> _saveAddRepeat(RepeatType type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_addRepeatKey, type.name);
    } catch (_) {}
  }

  Future<void> _saveAddUrgent(bool urgent) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_addUrgentKey, urgent);
    } catch (_) {}
  }

  // Keys for persisting filter/sort per context
  String get _filterKey =>
      widget.isPaired ? 'filter_shared' : 'filter_personal';
  String get _sortKey => widget.isPaired ? 'sort_shared' : 'sort_personal';
  String get _addRepeatKey => 'add_default_repeat';
  String get _addUrgentKey => 'add_default_urgent';

  Future<void> _loadFilterSortPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFilter = prefs.getString(_filterKey);
      final savedSort = prefs.getString(_sortKey);
      if (!mounted) return;
      setState(() {
        if (savedFilter == 'all' ||
            savedFilter == 'mine' ||
            savedFilter == 'partner') {
          _filter = savedFilter!;
        }
        if (savedSort == 'newest' || savedSort == 'oldest') {
          _sort = savedSort!;
        }
      });
    } catch (_) {}
  }

  Future<void> _updateFilter(String value) async {
    setState(() => _filter = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_filterKey, value);
    } catch (_) {}
  }

  Future<void> _updateSort(String value) async {
    setState(() => _sort = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sortKey, value);
    } catch (_) {}
  }

  Future<void> _renameTask(DuoTask task) async {
    final controller = TextEditingController(text: task.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Rename task'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => Navigator.of(ctx).pop(controller.text.trim()),
            decoration: const InputDecoration(
              hintText: 'Enter new title',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (newTitle == null) return;
    if (newTitle.isEmpty || newTitle == task.title) return;
    try {
      await Supabase.instance.client.from('tasks').update({
        'title': newTitle,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', task.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task renamed')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Rename failed: $e');
    }
  }

  List<DuoTask> _applyFiltersAndSort(List<DuoTask> tasks) {
    final userId = _safeUserId();
    Iterable<DuoTask> filtered = tasks;
    
    // Apply search filter first
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((task) {
        return task.title.toLowerCase().contains(query);
      });
    }
    
    // Determine active filter, allowing an override from widget.forcedFilter
    final activeFilter = widget.forcedFilter ?? _filter;
    if (widget.isPaired) {
      if (activeFilter == 'mine' && userId != null) {
        filtered = filtered.where((t) => t.ownerId == userId);
      } else if (activeFilter == 'partner' && userId != null) {
        filtered = filtered.where((t) => t.ownerId != userId);
      }
    } else {
      // Personal screen: filter is effectively 'all'
    }

    // Optional Today-only focus: keep tasks due today or overdue; if no due date, exclude by default
    if (widget.todayOnly) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      filtered = filtered.where((t) {
        final due = t.dueDate; // may be null
        if (due == null) return false; // focus strictly on scheduled items
        final d = DateTime(due.year, due.month, due.day);
        return d.isAtSameMomentAs(today) || d.isBefore(today);
      });
    }
    final list = filtered.toList();
    list.sort((a, b) => (_sort == 'newest')
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));
    return list;
  }

  String? _safeUserId() {
    if (widget.disableRealtime) return null;
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  Widget _buildFilterSortChips() {
    if (widget.hideFilterChips) return const SizedBox.shrink();
    final isShared = widget.isPaired;
    final partnerAvailable = _hasPartner;
    return Container(
      alignment: Alignment.centerLeft,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          // Filter chips
          ChoiceChip(
            label: const Text('All'),
            selected: _filter == 'all',
            onSelected: (_) => _updateFilter('all'),
          ),
          if (isShared)
            ChoiceChip(
              label: const Text('Mine'),
              selected: _filter == 'mine',
              onSelected:
                  partnerAvailable ? (_) => _updateFilter('mine') : null,
              labelStyle: TextStyle(
                color: partnerAvailable ? null : Colors.grey,
              ),
            ),
          if (isShared)
            ChoiceChip(
              label: const Text("Partner"),
              selected: _filter == 'partner',
              onSelected:
                  partnerAvailable ? (_) => _updateFilter('partner') : null,
              labelStyle: TextStyle(
                color: partnerAvailable ? null : Colors.grey,
              ),
            ),
          const SizedBox(width: 12),
          // Sort chips
          ChoiceChip(
            label: const Text('Newest'),
            selected: _sort == 'newest',
            onSelected: (_) => _updateSort('newest'),
          ),
          ChoiceChip(
            label: const Text('Oldest'),
            selected: _sort == 'oldest',
            onSelected: (_) => _updateSort('oldest'),
          ),
        ],
      ),
    );
  }

  String? _error;
  final _newTaskController = TextEditingController();
  // Removed unused _isSharedTask
  RepeatType _repeatType = RepeatType.none;
  String _searchQuery = '';
  DateTime? _selectedDueDate;
  TimeOfDay? _selectedDueTime;
  String? _partnerName;
  bool _partnerNameLoading = false;
  Stream<List<Map<String, dynamic>>>? _usrStream;
  StreamSubscription<List<Map<String, dynamic>>>? _usrSub;
  bool _hasPartner = false; // actual pairing state from usr.paired_with

  // Debounce mechanism to prevent rapid updates
  String? _lastUpdatedTaskId;
  DateTime? _lastUpdateTime;
  static const Duration _debounceDelay = Duration(milliseconds: 500);
  DuoTask? _lastDeletedTask;

  // Filters & sorting
  String _filter = 'all'; // all | mine | partner (partner only in shared)
  String _sort = 'newest'; // newest | oldest

  // Add dialog defaults
  bool _addUrgent = false;

  // Cute features
  late ConfettiController _confettiController;
  String _friendlyMessage = '';
  bool _showFriendlyMessage = false;

  // Supabase realtime channel
  Stream<List<DuoTask>>? _tasksStream;
  late final TaskService _taskService =
      widget.taskServiceOverride ?? TaskService();

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _setRandomFriendlyMessage();
    if (!widget.disableRealtime) {
      _setupTasksStream();
      _watchPartnerName();
    } else {
      // For tests: provide a basic stream so UI can render
      // Use a dummy user id and pair flag to pick shared vs personal
      final userId = 'test_user';
      _tasksStream = _taskService.getTaskStream(userId: userId);
      setState(() {});
    }
    _loadFilterSortPrefs();
    _loadAddDefaults();
  }

  @override
  void didUpdateWidget(covariant TaskScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When switching between shared/personal in the same element tree (tests),
    // reset and reload per-tab preferences so state does not leak across tabs.
    if (oldWidget.isPaired != widget.isPaired) {
      setState(() {
        _filter = 'all';
        _sort = 'newest';
      });
      _loadFilterSortPrefs();
    }
    // Re-wire tasks stream appropriately when toggling disableRealtime or tab.
    if (oldWidget.disableRealtime != widget.disableRealtime ||
        oldWidget.isPaired != widget.isPaired) {
          if (widget.disableRealtime) {
      final userId = 'test_user';
      _tasksStream = _taskService.getTaskStream(userId: userId);
      setState(() {});
    } else {
        _setupTasksStream();
        _watchPartnerName();
      }
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _usrSub?.cancel();
    super.dispose();
  }

  void _setRandomFriendlyMessage() {
    final messages = [
      "You're doing amazing! ",
      "Teamwork makes the dream work! ",
      "You two are unstoppable! ",
      "Another task conquered! ",
      "Your partner is lucky to have you! ",
      "Small steps, big progress! ",
      "You've got this! ",
      "Making it happen together! ",
      "Every task completed is a win! ",
      "You're building something beautiful! ",
    ];
    _friendlyMessage = messages[DateTime.now().millisecond % messages.length];
  }

  // _subscribeToChanges removed; realtime handled by _setupTasksStream

  void _setupTasksStream() {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    if (widget.isPaired) {
      // Fetch partner id and build shared tasks stream via TaskService
      client
          .from('usr')
          .select('paired_with')
          .eq('id', user.id)
          .maybeSingle()
          .then((row) {
        if (!mounted) return;
        final pairId = row?['paired_with'] as String?;
        _tasksStream = _taskService.getTaskStream(userId: user.id);
        setState(() {});
      });
    } else {
      _tasksStream = _taskService.getTaskStream(userId: user.id);
      setState(() {});
    }
  }

  void _watchPartnerName() {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    _usrStream =
        client.from('usr').stream(primaryKey: ['id']).eq('id', user.id);
    _usrSub = _usrStream!.listen((rows) async {
      if (!mounted || rows.isEmpty) return;
      final row = rows.first;
      final partnerId = row['paired_with'] as String?;
      if (partnerId == null) {
        if (mounted) {
          setState(() {
            _hasPartner = false;
            _partnerName = null;
            _partnerNameLoading = false;
          });
        }
        // Refresh stream when unpaired
        _setupTasksStream();
        return;
      }
      if (mounted) {
        setState(() {
          _hasPartner = true;
        });
      }
      // Prefer paired_with_name if present in the streamed row
      final pairedWithName = row['paired_with_name'] as String?;
      if (pairedWithName != null && pairedWithName.isNotEmpty) {
        if (mounted) {
          setState(() {
            _partnerName = pairedWithName;
            _partnerNameLoading = false;
          });
        }
        _setupTasksStream();
        return;
      }
      // Otherwise try a one-off fetch for the partner's name
      if (mounted) setState(() => _partnerNameLoading = true);
      // Safety: auto-dismiss the loading state after a short timeout to avoid sticky spinner
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        if (_partnerNameLoading &&
            (_partnerName == null || _partnerName!.isEmpty)) {
          setState(() {
            _partnerNameLoading = false;
          });
        }
      });
      try {
        final partner = await Supabase.instance.client
            .from('usr')
            .select('name')
            .eq('id', partnerId)
            .maybeSingle();
        if (!mounted) return;
        setState(() {
          _partnerName = partner?['name'] as String?; // May remain null
          _partnerNameLoading = false;
        });
        // Refresh stream when paired
        _setupTasksStream();
      } catch (_) {
        if (mounted) setState(() => _partnerNameLoading = false);
      }
    });
  }

  // _loadTasks and _showCompleteProfileDialog removed; handled by stream and onboarding/profile flow

  Future<void> _addTask() async {
    final title = _newTaskController.text.trim();
    if (title.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      final userData = await Supabase.instance.client
          .from('usr')
          .select('paired_with')
          .eq('id', user.id)
          .maybeSingle();
      if (userData == null) {
        throw Exception(
            'User profile not found in usr table. Please sign out and sign in again, or contact support.');
      }
      final pairId = userData['paired_with'] as String?; // UUID of partner
          final id = Uuid().v4();
      
      // Only check for pairing if we're trying to create a paired task
      // Personal tasks (widget.isPaired = false) should always be allowed
      if (widget.isPaired && (pairId == null || pairId.isEmpty)) {
        // Not paired, prompt to pair first for paired tasks only
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'You must pair with a partner to create paired tasks.'),
                backgroundColor: Colors.red),
          );
        }
        widget.onPairStatusChanged?.call();
        return;
      }
      await Supabase.instance.client.from('tasks').insert({
        'id': id,
        'title': title,
        'status': 'unclaimed',
        'owner_id': user.id,
        'pair_id': widget.isPaired ? pairId : null,
        'repeat_type': _repeatType.name,
        'due_date': _selectedDueDate?.toIso8601String(),
        'due_time': _selectedDueTime != null
            ? DateTime(2024, 1, 1, _selectedDueTime!.hour,
                    _selectedDueTime!.minute)
                .toIso8601String()
            : null,
        'urgent': _addUrgent,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      _newTaskController.clear();
      // Keep user's defaults for next time
      _selectedDueDate = null;
      _selectedDueTime = null;
      // Show snackbar for success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Task added!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Future<String?> getPartnerFcmToken(String partnerId) async {
  //   final response = await Supabase.instance.client
  //       .from('usr')
  //       .select('fcm_token')
  //       .eq('id', partnerId)
  //       .maybeSingle();
  //   return response?['fcm_token'] as String?;
  // }

  // Future<void> notifyPartner(String partnerFcmToken, String title, String body) async {
  //   final response = await http.post(
  //     Uri.parse('https://xqhlnuvpogiolzkucupt.supabase.co/functions/v1/send-fcm'), // TODO: Replace with your project ref
  //     headers: {'Content-Type': 'application/json'},
  //     body: jsonEncode({
  //       'fcmToken': partnerFcmToken,
  //       'title': title,
  //       'body': body,
  //     }),
  //   );
  //   if (response.statusCode != 200) {
  //     print('Failed to send notification:  [38;5;246m${response.body} [0m');
  //   }
  // }

  Future<void> _updateTaskStatus(DuoTask task, TaskStatus status) async {
    // Debounce rapid updates
    final now = DateTime.now();
    if (_lastUpdatedTaskId == task.id &&
        _lastUpdateTime != null &&
        now.difference(_lastUpdateTime!) < _debounceDelay) {
      Log.info('Debouncing rapid update for task ${task.id}');
      return;
    }
    _lastUpdatedTaskId = task.id;
    _lastUpdateTime = now;

    if (!mounted) return;
    setState(() {
      _error = null;
    });
    try {
      await Supabase.instance.client.from('tasks').update({
        'status': status.name,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', task.id);

      // Show celebration for completed tasks
      if (status == TaskStatus.done) {
        _confettiController.play();
        _setRandomFriendlyMessage();
        if (mounted) {
          setState(() {
            _showFriendlyMessage = true;
          });
        }

        // Show enhanced celebration
        final user = Supabase.instance.client.auth.currentUser;
        final isPartnerTask = user != null && task.ownerId != user.id;
        
        CelebrationService.showTaskCompletion(
          context: context,
          task: task,
          isPartnerTask: isPartnerTask,
          partnerName: isPartnerTask ? 'Partner' : null,
        );

        // Hide friendly message after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showFriendlyMessage = false;
            });
          }
        });
      }

      // No need to reload tasks; stream will update automatically
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      // No need to set loading; stream will update automatically
    }
  }

  Future<void> _toggleTaskRepeat(DuoTask task) async {
    setState(() {
      _error = null;
    });
    try {
      // Cycle: none -> daily -> weekly -> monthly -> yearly -> none
      final newRepeatType = () {
        switch (task.repeatType) {
          case RepeatType.none:
            return RepeatType.daily;
          case RepeatType.daily:
            return RepeatType.weekly;
          case RepeatType.weekly:
            return RepeatType.monthly;
          case RepeatType.monthly:
            return RepeatType.yearly;
          case RepeatType.yearly:
            return RepeatType.none;
        }
      }();
      await Supabase.instance.client.from('tasks').update({
        'repeat_type': newRepeatType.name,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', task.id);
      // No need to reload tasks; stream will update automatically
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      // No need to set loading; stream will update automatically
    }
  }

  Future<void> _deleteTask(DuoTask task) async {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      _lastDeletedTask = task;
      await Supabase.instance.client.from('tasks').delete().eq('id', task.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Task deleted'),
          backgroundColor: Colors.black87,
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () async {
              // Cache messenger to avoid using context after await
              final messenger = ScaffoldMessenger.of(context);
              final t = _lastDeletedTask;
              if (t == null) return;
              try {
                final map = t.toMap();
                // Update updated_at on restore
                map['updated_at'] = DateTime.now().toIso8601String();
                await Supabase.instance.client.from('tasks').insert(map);
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(
                      content: Text('Task restored'),
                      backgroundColor: Colors.green),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                      content: Text('Restore failed: $e'),
                      backgroundColor: Colors.red),
                );
              } finally {
                _lastDeletedTask = null;
              }
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted)
        setState(() {
          _error = 'Delete failed: $e';
        });
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  Future<void> _toggleTaskUrgent(DuoTask task) async {
    setState(() {
      _error = null;
    });
    try {
      await Supabase.instance.client.from('tasks').update({
        'urgent': !task.urgent,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', task.id);
      // No need to reload tasks; stream will update automatically
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      // No need to set loading; stream will update automatically
    }
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _newTaskController,
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  hintText: 'Enter task description...',
                ),
                autofocus: true,
                onSubmitted: (_) => _addTaskAndClose(),
              ),
              const SizedBox(height: 16),

              // Due Date Section
              const Row(
                children: [
                  Icon(Icons.calendar_today, size: 20),
                  SizedBox(width: 8),
                  Text('Due Date',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),

              // Quick due date options
              Wrap(
                spacing: 8,
                children: [
                  _buildQuickDateChip('Today', DateTime.now(), setState),
                  _buildQuickDateChip('Tomorrow',
                      DateTime.now().add(const Duration(days: 1)), setState),
                  _buildQuickDateChip('This Week',
                      DateTime.now().add(const Duration(days: 7)), setState),
                  _buildQuickDateChip('Next Week',
                      DateTime.now().add(const Duration(days: 14)), setState),
                ],
              ),

              const SizedBox(height: 8),

              // Custom date picker
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedDueDate != null
                                ? Icons.event
                                : Icons.event_busy,
                            color: _selectedDueDate != null
                                ? Colors.green
                                : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedDueDate != null
                                  ? _formatDateForDisplay(_selectedDueDate!)
                                  : 'Pick a custom date',
                              style: TextStyle(
                                color: _selectedDueDate != null
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey[600],
                                fontWeight: _selectedDueDate != null
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _showDatePicker(setState),
                    icon: const Icon(Icons.calendar_month),
                    tooltip: 'Pick date',
                  ),
                  if (_selectedDueDate != null)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _selectedDueDate = null;
                          _selectedDueTime = null;
                        });
                      },
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear date',
                    ),
                ],
              ),

              // Time picker (if date is selected)
              if (_selectedDueDate != null) ...[
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.access_time, size: 20),
                    SizedBox(width: 8),
                    Text('Due Time',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selectedDueTime != null
                                  ? Icons.schedule
                                  : Icons.schedule_outlined,
                              color: _selectedDueTime != null
                                  ? Colors.green
                                  : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedDueTime != null
                                    ? _selectedDueTime!.format(context)
                                    : 'No specific time',
                                style: TextStyle(
                                  color: _selectedDueTime != null
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _showTimePicker(setState),
                      icon: const Icon(Icons.access_time),
                      tooltip: 'Pick time',
                    ),
                    if (_selectedDueTime != null)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _selectedDueTime = null;
                          });
                        },
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear time',
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Repeat options
              Row(
                children: [
                  const Icon(Icons.repeat, size: 20),
                  const SizedBox(width: 8),
                  const Text('Repeat',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  DropdownButton<RepeatType>(
                    value: _repeatType,
                    items: RepeatType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.name.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _repeatType = value!);
                      _saveAddRepeat(value!);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),
              // Urgent toggle
              Row(
                children: [
                  const Icon(Icons.priority_high, size: 20),
                  const SizedBox(width: 8),
                  const Text('Urgent',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Switch(
                    value: _addUrgent,
                    onChanged: (v) {
                      setState(() => _addUrgent = v);
                      _saveAddUrgent(v);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _addTaskAndClose,
              child: const Text('Add Task'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDateChip(
      String label, DateTime date, StateSetter setState) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        setState(() {
          _selectedDueDate = date;
          _selectedDueTime = null; // Clear time if date is selected
        });
      },
      backgroundColor: _selectedDueDate == date
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: _selectedDueDate == date
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
        ),
      ),
    );
  }

  void _showDatePicker(StateSetter setState) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  void _showTimePicker(StateSetter setState) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedDueTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDueTime = picked;
      });
    }
  }

  void _addTaskAndClose() async {
    await _addTask();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  String _formatDateForDisplay(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final taskDate = DateTime(date.year, date.month, date.day);

    if (taskDate == today) return 'Today';
    if (taskDate == tomorrow) return 'Tomorrow';

    // Format as "Jan 15" or "Jan 15, 2024" if different year
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final month = monthNames[date.month - 1];
    final day = date.day;
    final year = date.year;

    if (year == now.year) {
      return '$month $day';
    } else {
      return '$month $day, $year';
    }
  }

  Widget _buildPairingSection() {
    final displayPartnerName = _partnerName ?? widget.partnerNameFromParent;
    // Consider the user paired on this screen if the Shared tab is active (widget.isPaired)
    // or if we have a partner name from stream/parent. Do NOT require a name to show paired state.
    final isPairedNow = widget.isPaired ||
        (displayPartnerName != null && displayPartnerName.isNotEmpty);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.blue.shade100, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPairedNow ? Icons.favorite : Icons.people,
            color: Colors.blueAccent,
            size: 32,
          ),
          const SizedBox(height: 10),
          Text(
            isPairedNow
                ? (displayPartnerName != null && displayPartnerName.isNotEmpty
                    ? 'Paired with $displayPartnerName'
                    : 'Paired')
                : 'Ready to Pair Up?',
            style: const TextStyle(
              color: Colors.blueAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          if (isPairedNow && _partnerNameLoading)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Fetching partner name…',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
              ],
            )
          else
            Text(
              isPairedNow
                  ? 'You can create shared tasks together'
                  : 'Connect with your partner to unlock shared tasks',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(
                isPairedNow ? Icons.settings : Icons.people_alt,
                color: Colors.white,
              ),
              label: Text(isPairedNow ? 'Manage Pair' : 'Pair with Partner'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: () {
                if (widget.onOpenPairTab != null) {
                  widget.onOpenPairTab!();
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PairingScreen()),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskSection(String title, List<DuoTask> tasks) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Padding(
                padding: const EdgeInsets.all(2.0),
                child: Builder(
                  builder: (context) {
                    // Avoid direct Supabase access in tests; use safe helper.
                    final userId = _safeUserId();
                    if (!widget.isPaired ||
                        userId == null ||
                        task.pairId == null) {
                      return TaskBubble(
                        task: task,
                        tabType: 'tasks',
                        onTap: () => _renameTask(task),
                      );
                    }
                    // If AppDependencies isn't in the tree (e.g., during tests), render without handoff stream
                    final inherited =
                        context.getElementForInheritedWidgetOfExactType<
                            AppDependencies>();
                    if (inherited == null) {
                      return TaskBubble(
                        task: task,
                        tabType: 'tasks',
                        onTap: () => _renameTask(task),
                      );
                    }
                    final deps = inherited.widget as AppDependencies;
                    return TaskBubble(
                      task: task,
                      tabType: 'tasks',
                      onTap: () => _renameTask(task),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildErrorBanner(),
            if (_isLoading) const LinearProgressIndicator(minHeight: 3),
            // Main content below
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.3),
                      Theme.of(context).colorScheme.surface,
                    ],
                  ),
                ),
                child: StreamBuilder<List<DuoTask>>(
                  stream: _tasksStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red)),
                      );
                    }
                    final tasks = snapshot.data ?? [];
                    final shownTasks = _applyFiltersAndSort(tasks);
                    return Column(
                      children: [
                        if (!widget.isPaired) _buildPairingSection(),
                        // Search bar
                        if (tasks.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: TaskSearchBar(
                              searchQuery: _searchQuery,
                              onSearchChanged: (query) {
                                setState(() {
                                  _searchQuery = query;
                                });
                              },
                            ),
                          ),
                        if (tasks.isNotEmpty) _buildFilterSortChips(),
                        if (shownTasks.isNotEmpty)
                          Expanded(
                            child: _buildTaskSection(
                              widget.isPaired
                                  ? 'Shared Tasks'
                                  : 'Personal Tasks',
                              shownTasks,
                            ),
                          ),
                        if (shownTasks.isEmpty)
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.task_alt,
                                      size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text('No tasks yet!',
                                      style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey[600])),
                                  const SizedBox(height: 8),
                                  Text(
                                      'Tap the + button to add your first task',
                                      style:
                                          TextStyle(color: Colors.grey[500])),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _showAddTaskDialog,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add your first task'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                      backgroundColor:
                                          Theme.of(context).colorScheme.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        // Confetti overlay (skip in tests for stability)
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
        // When embedded, still provide a small '+' button to add tasks
        if (widget.embedded)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.small(
              onPressed: _showAddTaskDialog,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
          ),
        if (_showFriendlyMessage)
          Positioned(
            top: 100,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green[300]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _friendlyMessage,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    if (widget.embedded) return bodyContent;

    return Scaffold(
      body: bodyContent,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

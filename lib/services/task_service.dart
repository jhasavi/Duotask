import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../models/task.dart';
import 'notification_service.dart';

class TaskService extends ChangeNotifier {
  final SupabaseClient _supabase;
  final NotificationService? _notificationService;
  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _errorMessage;
  RealtimeChannel? _taskChannel;
  String? _currentUserId;

  TaskService(this._supabase, [this._notificationService]);

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Task> get unclaimedTasks =>
      _tasks.where((t) => t.status == TaskStatus.unclaimed).toList();
  List<Task> get claimedTasks =>
      _tasks.where((t) => t.status == TaskStatus.claimed).toList();
  List<Task> get completedTasks =>
      _tasks.where((t) => t.status == TaskStatus.completed).toList();

  Future<void> loadTasks(String userId) async {
    _setLoading(true);
    _clearError();
    _currentUserId = userId;

    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .or('created_by_id.eq.$userId,assigned_to_id.eq.$userId,claimed_by_id.eq.$userId')
          .order('created_at', ascending: false);

      _tasks = (response as List).map((json) => Task.fromJson(json)).toList();
      _setLoading(false);
      _setupRealtimeSubscription(userId);
    } on SocketException {
      _setError('No internet connection. Please check your network.');
      _setLoading(false);
    } on PostgrestException catch (e) {
      _setError('Failed to load tasks: ${e.message}');
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load tasks. Please try again.');
      if (kDebugMode) print('Load tasks error: $e');
      _setLoading(false);
    }
  }

  void _setupRealtimeSubscription(String userId) {
    _taskChannel?.unsubscribe();

    _taskChannel = _supabase
        .channel('tasks:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          callback: (payload) {
            _handleRealtimeUpdate(payload);
          },
        )
        .subscribe();
  }

  void _handleRealtimeUpdate(PostgresChangePayload payload) async {
    final eventType = payload.eventType;
    final newRecord = payload.newRecord;
    final oldRecord = payload.oldRecord;

    switch (eventType) {
      case PostgresChangeEvent.insert:
        if (newRecord != null) {
          final task = Task.fromJson(newRecord);
          _tasks.insert(0, task);
          notifyListeners();
        }
        break;
      case PostgresChangeEvent.update:
        if (newRecord != null) {
          final task = Task.fromJson(newRecord);
          final index = _tasks.indexWhere((t) => t.id == task.id);
          if (index != -1) {
            final oldTask = _tasks[index];
            _tasks[index] = task;
            
            // Check if partner claimed or completed the task
            if (_notificationService != null && 
                _currentUserId != null && 
                task.createdById == _currentUserId &&
                oldRecord != null) {
              
              // Partner claimed task
              if (oldTask.status == TaskStatus.unclaimed && 
                  task.status == TaskStatus.claimed &&
                  task.claimedById != _currentUserId) {
                // Get partner name from task or use default
                await _notificationService!.showTaskClaimedNotification(
                  task,
                  'Your partner',
                );
              }
              
              // Partner completed task
              if (oldTask.status != TaskStatus.completed && 
                  task.status == TaskStatus.completed &&
                  task.claimedById != _currentUserId) {
                await _notificationService!.showTaskCompletedNotification(
                  task,
                  'Your partner',
                );
              }
            }
            
            notifyListeners();
          }
        }
        break;
      case PostgresChangeEvent.delete:
        if (oldRecord != null) {
          _tasks.removeWhere((t) => t.id == oldRecord['id']);
          notifyListeners();
        }
        break;
      default:
        break;
    }
  }

  Future<Task?> createTask({
    required String title,
    required String userId,
    String? description,
    String? assignedToId,
    TaskPriority priority = TaskPriority.normal,
    TaskRecurrence recurrence = TaskRecurrence.none,
    DateTime? dueDate,
    bool isPersonal = false,
    TaskVisibility visibility = TaskVisibility.personal,
    String? pairId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final taskId = const Uuid().v4();
      final now = DateTime.now();

      final taskData = {
        'id': taskId,
        'title': title,
        'description': description,
        'created_by_id': userId,
        'assigned_to_id': assignedToId,
        'status': TaskStatus.unclaimed.name,
        'priority': priority.name,
        'recurrence': recurrence.name,
        'due_date': dueDate?.toIso8601String(),
        'created_at': now.toIso8601String(),
        'is_personal': isPersonal, // Kept for backward compatibility
        'visibility': visibility.name,
        'pair_id': pairId,
      };

      final response =
          await _supabase.from('tasks').insert(taskData).select().single();

      final task = Task.fromJson(response);
      
      // Schedule notification if task has a due date
      if (task.dueDate != null && _notificationService != null) {
        await _notificationService!.scheduleTaskReminder(task);
      }
      
      _setLoading(false);
      return task;
    } on SocketException {
      _setError('No internet connection. Task not created.');
      _setLoading(false);
      return null;
    } on PostgrestException catch (e) {
      _setError('Failed to create task: ${e.message}');
      _setLoading(false);
      return null;
    } catch (e) {
      _setError('Failed to create task. Please try again.');
      if (kDebugMode) print('Create task error: $e');
      _setLoading(false);
      return null;
    }
  }

  Future<bool> updateTask(Task task) async {
    _setLoading(true);
    _clearError();

    try {
      await _supabase.from('tasks').update(task.toJson()).eq('id', task.id);

      _setLoading(false);
      return true;
    } on SocketException {
      _setError('No internet connection. Changes not saved.');
      _setLoading(false);
      return false;
    } on PostgrestException catch (e) {
      _setError('Failed to update task: ${e.message}');
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to update task. Please try again.');
      if (kDebugMode) print('Update task error: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> claimTask(String taskId, String userId) async {
    _setLoading(true);
    _clearError();

    try {
      await _supabase.from('tasks').update({
        'claimed_by_id': userId,
        'status': TaskStatus.claimed.name,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', taskId);

      _setLoading(false);
      return true;
    } on SocketException {
      _setError('No internet connection. Cannot claim task.');
      _setLoading(false);
      return false;
    } on PostgrestException catch (e) {
      _setError('Failed to claim task: ${e.message}');
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to claim task. Please try again.');
      if (kDebugMode) print('Claim task error: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> completeTask(String taskId) async {
    _setLoading(true);
    _clearError();

    try {
      await _supabase.from('tasks').update({
        'status': TaskStatus.completed.name,
        'completed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', taskId);

      _setLoading(false);
      return true;
    } on SocketException {
      _setError('No internet connection. Cannot complete task.');
      _setLoading(false);
      return false;
    } on PostgrestException catch (e) {
      _setError('Failed to complete task: ${e.message}');
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to complete task. Please try again.');
      if (kDebugMode) print('Complete task error: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> unclaimTask(String taskId) async {
    _setLoading(true);
    _clearError();

    try {
      await _supabase.from('tasks').update({
        'claimed_by_id': null,
        'status': TaskStatus.unclaimed.name,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', taskId);

      _setLoading(false);
      return true;
    } on SocketException {
      _setError('No internet connection. Cannot unclaim task.');
      _setLoading(false);
      return false;
    } on PostgrestException catch (e) {
      _setError('Failed to unclaim task: ${e.message}');
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to unclaim task. Please try again.');
      if (kDebugMode) print('Unclaim task error: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> cycleTaskStatus(Task task, String userId) async {
    _setLoading(true);
    _clearError();

    try {
      // Use RPC function for atomic status transition (prevents race conditions)
      final response = await _supabase.rpc('cycle_task_status', params: {
        'task_uuid': task.id,
        'user_uuid': userId,
      }).select().single();

      if (response != null) {
        // Update local task list
        final index = _tasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          final updatedTask = Task.fromJson({
            ...task.toJson(),
            'status': response['status'],
            'claimed_by_id': response['claimed_by_id'],
            'claimed_at': response['claimed_at'],
            'completed_at': response['completed_at'],
            'updated_at': response['updated_at'],
          });
          
          _tasks[index] = updatedTask;
          
          // Create recurring task if completed and has recurrence
          if (updatedTask.status == TaskStatus.completed &&
              task.recurrence != TaskRecurrence.none) {
            await createRecurringTask(task);
          }
          
          notifyListeners();
        }
        
        _setLoading(false);
        return true;
      }
      
      _setLoading(false);
      return false;
    } on SocketException {
      _setError('No internet connection. Cannot update task.');
      _setLoading(false);
      return false;
    } on PostgrestException catch (e) {
      // Check for ownership lock error
      if (e.message.contains('Only the task owner can complete')) {
        _setError('Only the task owner can complete this task');
      } else {
        _setError('Failed to update task: ${e.message}');
      }
      if (kDebugMode) print('Cycle task status error: ${e.message}');
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to update task. Please try again.');
      if (kDebugMode) print('Cycle task status error: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deleteTask(String taskId) async {
    _setLoading(true);
    _clearError();

    try {
      await _supabase.from('tasks').delete().eq('id', taskId);

      _setLoading(false);
      return true;
    } on SocketException {
      _setError('No internet connection. Cannot delete task.');
      _setLoading(false);
      return false;
    } on PostgrestException catch (e) {
      _setError('Failed to delete task: ${e.message}');
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to delete task. Please try again.');
      if (kDebugMode) print('Delete task error: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<Task?> createRecurringTask(Task originalTask) async {
    DateTime? newDueDate;

    if (originalTask.dueDate != null) {
      switch (originalTask.recurrence) {
        case TaskRecurrence.daily:
          newDueDate = originalTask.dueDate!.add(const Duration(days: 1));
          break;
        case TaskRecurrence.weekly:
          newDueDate = originalTask.dueDate!.add(const Duration(days: 7));
          break;
        case TaskRecurrence.none:
          break;
      }
    }

    return await createTask(
      title: originalTask.title,
      userId: originalTask.createdById,
      description: originalTask.description,
      assignedToId: originalTask.assignedToId,
      priority: originalTask.priority,
      recurrence: originalTask.recurrence,
      dueDate: newDueDate,
      isPersonal: originalTask.isPersonal,
    );
  }

  // Parse natural language task input
  Map<String, dynamic> parseNaturalInput(String input) {
    final result = <String, dynamic>{
      'title': input,
      'priority': TaskPriority.normal,
      'dueDate': null,
    };

    // Check for urgent indicator
    if (input.toLowerCase().contains('urgent') ||
        input.toLowerCase().contains('asap') ||
        input.toLowerCase().contains('!')) {
      result['priority'] = TaskPriority.urgent;
      result['title'] = input.replaceAll(RegExp(r'urgent|asap|!', caseSensitive: false), '').trim();
    }

    // Parse time patterns
    final timePattern = RegExp(r'@(\d{1,2}):?(\d{2})?\s*(am|pm)?', caseSensitive: false);
    final match = timePattern.firstMatch(input);

    if (match != null) {
      try {
        var hour = int.parse(match.group(1)!);
        final minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
        final ampm = match.group(3)?.toLowerCase();

        if (ampm == 'pm' && hour < 12) hour += 12;
        if (ampm == 'am' && hour == 12) hour = 0;

        final now = DateTime.now();
        var dueDate = DateTime(now.year, now.month, now.day, hour, minute);

        // If time has passed today, set for tomorrow
        if (dueDate.isBefore(now)) {
          dueDate = dueDate.add(const Duration(days: 1));
        }

        result['dueDate'] = dueDate;
        result['title'] = input.replaceAll(timePattern, '').trim();
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing time: $e');
        }
      }
    }

    // Parse relative time (tomorrow, tonight, etc.)
    if (input.toLowerCase().contains('tomorrow')) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      result['dueDate'] = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
      result['title'] = input.replaceAll(RegExp(r'tomorrow', caseSensitive: false), '').trim();
    } else if (input.toLowerCase().contains('tonight')) {
      final tonight = DateTime.now();
      result['dueDate'] = DateTime(tonight.year, tonight.month, tonight.day, 20, 0);
      result['title'] = input.replaceAll(RegExp(r'tonight', caseSensitive: false), '').trim();
    }

    return result;
  }

  /// Get weekly completion counts for user and partner
  Future<Map<String, int>> getWeeklyCompletions(
    String userId,
    String? partnerId,
  ) async {
    try {
      // Get current week's Sunday and next Sunday
      final now = DateTime.now();
      final sunday = now.subtract(Duration(days: now.weekday % 7));
      final startOfWeek = DateTime(sunday.year, sunday.month, sunday.day);
      final endOfWeek = startOfWeek.add(const Duration(days: 7));

      final response = await _supabase
          .from('tasks')
          .select('claimed_by_id')
          .eq('visibility', 'group')
          .eq('status', 'completed')
          .gte('completed_at', startOfWeek.toIso8601String())
          .lt('completed_at', endOfWeek.toIso8601String());

      int userCount = 0;
      int partnerCount = 0;

      for (final task in response as List) {
        final claimedById = task['claimed_by_id'] as String?;
        if (claimedById == userId) {
          userCount++;
        } else if (claimedById == partnerId) {
          partnerCount++;
        }
      }

      return {
        'user': userCount,
        'partner': partnerCount,
      };
    } catch (e) {
      if (kDebugMode) print('Get weekly completions error: $e');
      return {'user': 0, 'partner': 0};
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  @override
  void dispose() {
    _taskChannel?.unsubscribe();
    super.dispose();
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../utils/logger.dart';
import 'clean_pairing_service.dart';
import 'task_cache_service.dart';

/// Represents a paginated list of tasks
class PaginatedTasks {
  final List<DuoTask> tasks;
  final int currentPage;
  final int totalPages;
  final bool hasMore;

  const PaginatedTasks({
    required this.tasks,
    required this.currentPage,
    required this.totalPages,
    required this.hasMore,
  });
}

/// Service for managing tasks using Supabase
class TaskService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CleanPairingService _pairingService = CleanPairingService();
  final TaskCacheService _cacheService = TaskCacheService();
  static const int _pageSize = 20;

  /// Initialize the service
  Future<void> init() async {
    await _cacheService.init();
  }

  /// Get paginated tasks for a user
  Future<PaginatedTasks> getPaginatedTasks({
    required String userId,
    int page = 0,
    bool forceRefresh = false,
  }) async {
    try {
      // Try to get from cache first if it's the first page and not forcing refresh
      if (page == 0 && !forceRefresh) {
        final cachedTasks = await _cacheService.getCachedTasks(userId);
        if (cachedTasks != null) {
          return PaginatedTasks(
            tasks: cachedTasks,
            currentPage: 0,
            totalPages: 1, // We don't know the total pages from cache
            hasMore: false, // We don't know if there are more from cache
          );
        }
      }

      // Get current pairing status
      final pairInfo = await _pairingService.getCurrentPair();
      final currentPartnerId = pairInfo?['partner_id'] as String?;
      final currentPairId = pairInfo?['pair_id'] as String?;

      // Calculate range for pagination
      final from = page * _pageSize;
      final to = (page + 1) * _pageSize - 1;

      // Build the base query
      var query = _supabase
          .from('tasks')
          .select('*', const FetchOptions(count: 'exact'))
          .or('scope.eq.personal,scope.is.null')
          .eq('creator_id', userId)
          .order('created_at', ascending: false);

      // Add pair filter if in a pair
      if (currentPairId != null) {
        query = query.or('pair_id.eq.$currentPairId');
      }

      // Execute the query with pagination
      final response = await query.range(from, to);
      
      // Parse the response
      final tasks = (response as List)
          .map((t) => DuoTask.fromJson(t as Map<String, dynamic>))
          .toList();

      // Cache the results if it's the first page
      if (page == 0) {
        await _cacheService.cacheTasks(userId, tasks);
      }

      // Calculate pagination metadata
      final count = response.count ?? 0;
      final totalPages = (count / _pageSize).ceil();

      return PaginatedTasks(
        tasks: tasks,
        currentPage: page,
        totalPages: totalPages,
        hasMore: (page + 1) < totalPages,
      );
    } catch (e) {
      logger.e('Error fetching paginated tasks: $e');
      rethrow;
    }
  }

  /// Get a single task by ID with caching
  Future<DuoTask?> getTaskById(String taskId) async {
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('id', taskId)
          .single();
          
      return DuoTask.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      logger.e('Error fetching task $taskId: $e');
      return null;
    }
  }

  /// Clear the task cache for a user
  Future<void> clearCache(String userId) async {
    await _cacheService.clearCache(userId);
  }

  /// Get all tasks for a user (legacy method)
  @Deprecated('Use getPaginatedTasks instead for better performance')
  Future<List<DuoTask>> getTasks({required String userId}) async {
    final result = await getPaginatedTasks(userId: userId);
    return result.tasks;
  }

      print('Personal tasks: ${personalTasks.length}');
      
      List<Map<String, dynamic>> sharedTasks = [];
      
      if (currentPairId != null && pairInfo?['status'] == 'active') {
        // Get shared tasks for current active pairing
        final sharedTasksResponse = await _supabase
            .from('tasks')
            .select('*')
            .eq('scope', 'shared')
            .eq('pair_id', currentPairId)
            .order('created_at', ascending: false);
        
        sharedTasks = List<Map<String, dynamic>>.from(sharedTasksResponse);
        print('Shared tasks for current pairing: ${sharedTasks.length}');
      }

      final allTasks = <Map<String, dynamic>>[];
      allTasks.addAll(personalTasks as List<Map<String, dynamic>>);
      allTasks.addAll(sharedTasks);

      // Remove duplicates based on task ID
      final uniqueTasks = <String, Map<String, dynamic>>{};
      for (final task in allTasks) {
        uniqueTasks[task['id'] as String] = task;
      }

      final result = uniqueTasks.values
          .map((task) => DuoTask.fromJson(task))
          .toList();

      print('Found ${result.length} total tasks for user $userId');
      print('Task breakdown:');
      print('- Personal tasks: ${personalTasks.length}');
      print('- Shared tasks: ${sharedTasks.length}');
      
      return result;
    } catch (e) {
      Log.error('Failed to get tasks: $e');
      print('Error in getTasks: $e');
      rethrow;
    }
  }

  /// Create a new task
  Future<void> createTask(DuoTask task) async {
    try {
      if (task.pairId != null) {
        // Use the new function for shared tasks to automatically track pairing history
        await _supabase.rpc('create_task_with_pairing_history', params: {
          'p_title': task.title,
          'p_owner_id': task.ownerId,
          'p_pair_id': task.pairId,
          'p_status': task.status.name,
          'p_repeat_type': task.repeatType.name,
          'p_due_date': task.dueDate?.toIso8601String(),
          'p_urgent': task.urgent,
        });
      } else {
        // For personal tasks, use regular insert
        final taskData = {
          'id': task.id,
          'title': task.title,
          'status': task.status.name,
          'scope': 'personal',
          'creator_id': task.ownerId,
          'owner_id': task.ownerId,
          'pair_id': task.pairId,
          'repeat_type': task.repeatType.name,
          'due_date': task.dueDate?.toIso8601String(),
          'urgent': task.urgent,
          'created_at': task.createdAt.toIso8601String(),
          'updated_at': task.updatedAt.toIso8601String(),
        };
        
        // Only add claimed_by if it's not null
        if (task.claimedBy != null) {
          taskData['claimed_by'] = task.claimedBy;
        }
        
        await _supabase.from('tasks').insert(taskData);
      }
    } catch (e) {
      Log.error('Failed to create task: $e');
      rethrow;
    }
  }

  /// Update an existing task
  Future<void> updateTask(DuoTask task) async {
    try {
      await _supabase.from('tasks').update({
        'title': task.title,
        'status': task.status.name,
        'claimed_by': task.claimedBy,
        'repeat_type': task.repeatType.name,
        'due_date': task.dueDate?.toIso8601String(),
        'urgent': task.urgent,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', task.id);
    } catch (e) {
      Log.error('Failed to update task: $e');
      rethrow;
    }
  }

  /// Claim a task
  Future<void> claimTask(String taskId, String userId) async {
    try {
      await _supabase.from('tasks').update({
        'status': TaskStatus.claimed.name,
        'claimed_by': userId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', taskId);
    } catch (e) {
      Log.error('Failed to claim task: $e');
      rethrow;
    }
  }

  /// Complete a task
  Future<void> completeTask(String taskId, String userId) async {
    try {
      final task = await getTask(taskId);
      if (task == null) throw Exception('Task not found');
      
      // Update task status to done
      await _supabase
          .from('tasks')
          .update({
            'status': 'done',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId);
      
      // Schedule auto-delete based on user settings
      await _scheduleAutoDelete(taskId);
      
      Log.info('Task completed: $taskId');
    } catch (e) {
      Log.error('Error completing task: $e');
      rethrow;
    }
  }

  Future<DuoTask?> getTask(String taskId) async {
    try {
      final result = await _supabase
          .from('tasks')
          .select()
          .eq('id', taskId)
          .maybeSingle();
      
      if (result != null) {
        return DuoTask.fromJson(result);
      }
      return null;
    } catch (e) {
      Log.error('Error getting task: $e');
      return null;
    }
  }

  Future<void> _scheduleAutoDelete(String taskId) async {
    try {
      // Get user's auto-delete preference (default: 24 hours)
      final prefs = await SharedPreferences.getInstance();
      final autoDeleteHours = prefs.getInt('auto_delete_hours') ?? 24;
      
      // Schedule deletion
      final deleteTime = DateTime.now().add(Duration(hours: autoDeleteHours));
      
      // Store deletion schedule in database
      await _supabase
          .from('task_deletion_schedule')
          .upsert({
            'task_id': taskId,
            'delete_at': deleteTime.toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          });
      
      Log.info('Scheduled auto-delete for task $taskId in $autoDeleteHours hours');
    } catch (e) {
      Log.error('Error scheduling auto-delete: $e');
    }
  }

  Future<void> processAutoDeletions() async {
    try {
      final now = DateTime.now();
      
      // Get tasks scheduled for deletion
      final result = await _supabase
          .from('task_deletion_schedule')
          .select('task_id')
          .lt('delete_at', now.toIso8601String());
      
      if (result.isNotEmpty) {
        final taskIds = result.map((r) => r['task_id'] as String).toList();
        
        // Delete the tasks
        await _supabase
            .from('tasks')
            .delete()
            .inFilter('id', taskIds);
        
        // Remove from deletion schedule
        await _supabase
            .from('task_deletion_schedule')
            .delete()
            .inFilter('task_id', taskIds);
        
        Log.info('Auto-deleted ${taskIds.length} completed tasks');
      }
    } catch (e) {
      Log.error('Error processing auto-deletions: $e');
    }
  }

  Future<void> updateTaskStatus(String taskId, TaskStatus status) async {
    try {
      await _supabase
          .from('tasks')
          .update({
            'status': status.name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId);
      
      Log.info('Task status updated: $taskId -> ${status.name}');
    } catch (e) {
      Log.error('Error updating task status: $e');
      rethrow;
    }
  }

  Future<void> toggleTaskUrgent(String taskId) async {
    try {
      // Get current task to toggle urgent status
      final task = await getTask(taskId);
      if (task == null) throw Exception('Task not found');
      
      await _supabase
          .from('tasks')
          .update({
            'urgent': !task.urgent,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId);
      
      Log.info('Task urgent toggled: $taskId -> ${!task.urgent}');
    } catch (e) {
      Log.error('Error toggling task urgent: $e');
      rethrow;
    }
  }

  /// Delete a task
  Future<void> deleteTask(String taskId) async {
    try {
      await _supabase.from('tasks').delete().eq('id', taskId);
    } catch (e) {
      Log.error('Failed to delete task: $e');
      rethrow;
    }
  }

  /// Get a stream of tasks for real-time updates
  Stream<List<DuoTask>> getTaskStream({required String userId}) {
    return _supabase
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('owner_id', userId)
        .order('created_at', ascending: false)
        .map((response) => (response as List)
            .map((task) => DuoTask.fromJson(task))
            .toList());
  }

  /// Watch tasks with filtering and sorting
  Stream<List<DuoTask>> watchTasks({
    required String userId,
    String filter = 'all',
    String sort = 'newest',
    bool todayOnly = false,
  }) {
    // For now, use a simple stream without complex filtering
    // Complex filtering can be done in memory after fetching
    return _supabase
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('owner_id', userId)
        .order('created_at', ascending: sort == 'newest' ? false : true)
        .map((response) {
          var tasks = (response as List)
              .map((task) => DuoTask.fromJson(task))
              .toList();
          
          // Apply additional filters in memory
          if (filter == 'partner') {
            tasks = tasks.where((task) => task.ownerId != userId).toList();
          }
          
          if (todayOnly) {
            final today = DateTime.now();
            final startOfDay = DateTime(today.year, today.month, today.day);
            final endOfDay = startOfDay.add(const Duration(days: 1));
            tasks = tasks.where((task) {
              if (task.dueDate == null) return false;
              return task.dueDate!.isAfter(startOfDay) && 
                     task.dueDate!.isBefore(endOfDay);
            }).toList();
          }
          
          return tasks;
        });
  }
}

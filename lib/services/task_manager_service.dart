import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import '../utils/validation.dart';
import 'analytics_service.dart';

/// Comprehensive task management service
class TaskManagerService {
  static final TaskManagerService _instance = TaskManagerService._internal();
  factory TaskManagerService() => _instance;
  TaskManagerService._internal();

  final AnalyticsService _analytics = AnalyticsService();

  /// Create a new task with validation and analytics
  Future<DuoTask> createTask({
    required String title,
    required String ownerId,
    String? pairId,
    String? description,
    DateTime? dueDate,
    bool isUrgent = false,
    RepeatType repeatType = RepeatType.none,
    String? userId,
  }) async {
    // Validate input
    if (!Validation.isValidTaskTitle(title)) {
      throw TaskException('Invalid task title');
    }

    if (title.length > AppConstants.maxTaskTitleLength) {
      throw TaskException('Task title too long');
    }

    final task = DuoTask(
      id: const Uuid().v4(),
      title: title.trim(),
      status: TaskStatus.unclaimed,
      ownerId: ownerId,
      pairId: pairId,
      dueDate: dueDate,
      urgent: isUrgent,
      repeatType: repeatType,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      // Insert into Supabase
      await Supabase.instance.client.from('tasks').insert({
        'id': task.id,
        'title': task.title,
        'status': task.status.name,
        'owner_id': task.ownerId,
        'pair_id': task.pairId,
        'due_date': task.dueDate?.toIso8601String(),
        'urgent': task.urgent,
        'repeat_type': task.repeatType.name,
        'created_at': task.createdAt.toIso8601String(),
        'updated_at': task.updatedAt.toIso8601String(),
      });

      // Track analytics
      await _analytics.trackTaskCreated(
        taskId: task.id,
        taskTitle: task.title,
        isUrgent: task.urgent,
        userId: userId,
      );

      Log.info('Task created: ${task.title}');
      return task;
    } catch (e) {
      Log.error('Failed to create task: $e');
      throw TaskException('Failed to create task: $e');
    }
  }

  /// Update task with validation and analytics
  Future<DuoTask> updateTask({
    required String taskId,
    String? title,
    String? description,
    DateTime? dueDate,
    bool? isUrgent,
    RepeatType? repeatType,
    String? userId,
  }) async {
    try {
      // Get current task
      final response = await Supabase.instance.client
          .from('tasks')
          .select()
          .eq('id', taskId)
          .single();

      if (response == null) {
        throw TaskException('Task not found');
      }

      // Validate title if provided
      if (title != null && !Validation.isValidTaskTitle(title)) {
        throw TaskException('Invalid task title');
      }

      // Prepare update data
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (title != null) updateData['title'] = title.trim();
      if (description != null) updateData['description'] = description.trim();
      if (dueDate != null) updateData['due_date'] = dueDate.toIso8601String();
      if (isUrgent != null) updateData['urgent'] = isUrgent;
      if (repeatType != null) updateData['repeat_type'] = repeatType.name;

      // Update in Supabase
      await Supabase.instance.client
          .from('tasks')
          .update(updateData)
          .eq('id', taskId);

      // Track analytics
      await _analytics.trackUserAction(
        'task_updated',
        parameters: {
          'task_id': taskId,
          'updated_fields': updateData.keys.toList(),
        },
        userId: userId,
      );

      Log.info('Task updated: $taskId');
      
      // Return updated task
      return DuoTask.fromJson({...response, ...updateData});
    } catch (e) {
      Log.error('Failed to update task: $e');
      throw TaskException('Failed to update task: $e');
    }
  }

  /// Claim a task
  Future<void> claimTask({
    required String taskId,
    required String userId,
  }) async {
    try {
      await Supabase.instance.client
          .from('tasks')
          .update({
            'status': TaskStatus.claimed.name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId);

      await _analytics.trackUserAction(
        'task_claimed',
        parameters: {'task_id': taskId},
        userId: userId,
      );

      Log.info('Task claimed: $taskId by $userId');
    } catch (e) {
      Log.error('Failed to claim task: $e');
      throw TaskException('Failed to claim task: $e');
    }
  }

  /// Complete a task with analytics
  Future<void> completeTask({
    required String taskId,
    required String userId,
    Duration? completionTime,
  }) async {
    try {
      await Supabase.instance.client
          .from('tasks')
          .update({
            'status': TaskStatus.done.name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId);

      // Get task details for analytics
      final response = await Supabase.instance.client
          .from('tasks')
          .select('title')
          .eq('id', taskId)
          .single();

      await _analytics.trackTaskCompleted(
        taskId: taskId,
        taskTitle: response['title'],
        completionTime: completionTime,
        userId: userId,
      );

      Log.info('Task completed: $taskId by $userId');
    } catch (e) {
      Log.error('Failed to complete task: $e');
      throw TaskException('Failed to complete task: $e');
    }
  }

  /// Delete a task
  Future<void> deleteTask({
    required String taskId,
    required String userId,
  }) async {
    try {
      await Supabase.instance.client
          .from('tasks')
          .delete()
          .eq('id', taskId);

      await _analytics.trackUserAction(
        'task_deleted',
        parameters: {'task_id': taskId},
        userId: userId,
      );

      Log.info('Task deleted: $taskId by $userId');
    } catch (e) {
      Log.error('Failed to delete task: $e');
      throw TaskException('Failed to delete task: $e');
    }
  }

  /// Get tasks with advanced filtering
  Future<List<DuoTask>> getTasks({
    required String userId,
    String? pairId,
    String? status,
    bool? isUrgent,
    DateTime? dueDate,
    String? searchQuery,
    int? limit,
    int? offset,
    String sortBy = 'created_at',
    bool sortDescending = true,
  }) async {
    try {
      var queryBuilder = Supabase.instance.client
          .from('tasks')
          .select();

      // Apply filters
      if (pairId != null) {
        queryBuilder = queryBuilder.eq('pair_id', pairId);
      } else {
        queryBuilder = queryBuilder.eq('owner_id', userId);
      }

      if (status != null) {
        queryBuilder = queryBuilder.eq('status', status);
      }

      if (isUrgent != null) {
        queryBuilder = queryBuilder.eq('urgent', isUrgent);
      }

      if (dueDate != null) {
        final startOfDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        queryBuilder = queryBuilder
            .gte('due_date', startOfDay.toIso8601String())
            .lt('due_date', endOfDay.toIso8601String());
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryBuilder = queryBuilder.ilike('title', '%$searchQuery%');
      }

      // Apply sorting and pagination - chain operations without reassignment
      final finalQuery = queryBuilder
          .order(sortBy, ascending: !sortDescending)
          .limit(limit ?? 50);
      
      if (offset != null) {
        final response = await finalQuery.range(offset, offset + (limit ?? 50) - 1);
        return (response as List).map((task) => DuoTask.fromJson(task)).toList();
      } else {
        final response = await finalQuery;
        return (response as List).map((task) => DuoTask.fromJson(task)).toList();
      }
    } catch (e) {
      Log.error('Failed to get tasks: $e');
      throw TaskException('Failed to get tasks: $e');
    }
  }

  /// Get task statistics
  Future<Map<String, dynamic>> getTaskStats({
    required String userId,
    String? pairId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = Supabase.instance.client
          .from('tasks')
          .select('status, created_at, completed_at');

      if (pairId != null) {
        query = query.eq('pair_id', pairId);
      } else {
        query = query.eq('owner_id', userId);
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query;
      
      final stats = <String, int>{
        'total': response.length,
        'unclaimed': 0,
        'claimed': 0,
        'completed': 0,
        'urgent': 0,
      };

      for (final task in response) {
        final status = task['status'] as String;
        stats[status] = (stats[status] ?? 0) + 1;
        
        if (task['urgent'] == true) {
          stats['urgent'] = (stats['urgent'] ?? 0) + 1;
        }
      }

      return stats;
    } catch (e) {
      Log.error('Failed to get task stats: $e');
      throw TaskException('Failed to get task stats: $e');
    }
  }

  /// Bulk operations
  Future<void> bulkUpdateTasks({
    required List<String> taskIds,
    required Map<String, dynamic> updates,
    required String userId,
  }) async {
    try {
      await Supabase.instance.client
          .from('tasks')
          .update({
            ...updates,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .inFilter('id', taskIds);

      await _analytics.trackUserAction(
        'bulk_task_update',
        parameters: {
          'task_count': taskIds.length,
          'updated_fields': updates.keys.toList(),
        },
        userId: userId,
      );

      Log.info('Bulk updated ${taskIds.length} tasks');
    } catch (e) {
      Log.error('Failed to bulk update tasks: $e');
      throw TaskException('Failed to bulk update tasks: $e');
    }
  }

  /// Search tasks
  Future<List<DuoTask>> searchTasks({
    required String userId,
    required String query,
    String? pairId,
    int? limit,
  }) async {
    try {
      var searchQueryBuilder = Supabase.instance.client
          .from('tasks')
          .select()
          .ilike('title', '%$query%');

      if (pairId != null) {
        searchQueryBuilder = searchQueryBuilder.eq('pair_id', pairId);
      } else {
        searchQueryBuilder = searchQueryBuilder.eq('owner_id', userId);
      }

      // Chain operations without reassignment
      final finalSearchQuery = searchQueryBuilder.limit(limit ?? 50);
      final response = await finalSearchQuery;
      return (response as List).map((task) => DuoTask.fromJson(task)).toList();
    } catch (e) {
      Log.error('Failed to search tasks: $e');
      throw TaskException('Failed to search tasks: $e');
    }
  }
}

/// Custom exception for task operations
class TaskException implements Exception {
  final String message;
  
  TaskException(this.message);
  
  @override
  String toString() => 'TaskException: $message';
}

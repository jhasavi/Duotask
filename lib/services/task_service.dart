import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';

class TaskService {
  final SupabaseClient _client = Supabase.instance.client;

  // Get all tasks for a user
  Future<List<Task>> getTasks(String userId) async {
    try {
      final response = await _client
          .from('tasks')
          .select()
          .eq('owner_id', userId)
          .order('created_at', ascending: false);
      
      return response.map<Task>((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('Error getting tasks: $e');
      throw Exception('Failed to load tasks');
    }
  }

  // Create a new task
  Future<Task> createTask({
    required String title,
    String? description,
    required String userId,
    String? partnerId,
    DateTime? dueDate,
  }) async {
    try {
      final now = DateTime.now();
      final taskData = {
        'title': title,
        // Note: description column might not exist in database
        // 'description': description,
        'owner_id': userId,
        'pair_id': partnerId,
        'status': 'unclaimed',
        'due_date': dueDate?.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await _client
          .from('tasks')
          .insert(taskData)
          .select()
          .single();

      return Task.fromJson(response);
    } catch (e) {
      print('Error creating task: $e');
      throw Exception('Failed to create task');
    }
  }

  // Update a task
  Future<Task> updateTask(String taskId, Map<String, dynamic> updates) async {
    try {
      final updateData = {
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('tasks')
          .update(updateData)
          .eq('id', taskId)
          .select()
          .single();

      return Task.fromJson(response);
    } catch (e) {
      print('Error updating task: $e');
      throw Exception('Failed to update task');
    }
  }

  // Delete a task
  Future<void> deleteTask(String taskId) async {
    try {
      await _client
          .from('tasks')
          .delete()
          .eq('id', taskId);
    } catch (e) {
      print('Error deleting task: $e');
      throw Exception('Failed to delete task');
    }
  }

  // Get tasks by status
  Future<List<Task>> getTasksByStatus(String userId, String status) async {
    try {
      final response = await _client
          .from('tasks')
          .select()
          .eq('owner_id', userId)
          .eq('status', status)
          .order('created_at', ascending: false);
      
      return response.map<Task>((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('Error getting tasks by status: $e');
      throw Exception('Failed to load tasks');
    }
  }

  // Get personal tasks (owned by user)
  Future<List<Task>> getPersonalTasks(String userId) async {
    try {
      final response = await _client
          .from('tasks')
          .select()
          .eq('owner_id', userId)
          .order('created_at', ascending: false);
      
      // Filter out tasks that have a pair_id (shared tasks)
      final tasks = response.map<Task>((json) => Task.fromJson(json)).toList();
      return tasks.where((task) => task.pairId == null).toList();
    } catch (e) {
      print('Error getting personal tasks: $e');
      throw Exception('Failed to load personal tasks');
    }
  }

  // Get paired tasks (shared with partner)
  Future<List<Task>> getPairedTasks(String userId, String? partnerId) async {
    try {
      if (partnerId == null) {
        return [];
      }

      final response = await _client
          .from('tasks')
          .select()
          .or('owner_id.eq.$userId,owner_id.eq.$partnerId')
          .order('created_at', ascending: false);
      
      // Filter to only include tasks that have a pair_id (shared tasks)
      final tasks = response.map<Task>((json) => Task.fromJson(json)).toList();
      return tasks.where((task) => task.pairId != null).toList();
    } catch (e) {
      print('Error getting paired tasks: $e');
      throw Exception('Failed to load paired tasks');
    }
  }

  // Claim a task
  Future<Task> claimTask(String taskId, String userId) async {
    try {
      final response = await _client
          .from('tasks')
          .update({
            'status': 'claimed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId)
          .select()
          .single();

      return Task.fromJson(response);
    } catch (e) {
      print('Error claiming task: $e');
      throw Exception('Failed to claim task');
    }
  }

  // Complete a task
  Future<Task> completeTask(String taskId) async {
    try {
      final response = await _client
          .from('tasks')
          .update({
            'status': 'done',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId)
          .select()
          .single();

      return Task.fromJson(response);
    } catch (e) {
      print('Error completing task: $e');
      throw Exception('Failed to complete task');
    }
  }
} 
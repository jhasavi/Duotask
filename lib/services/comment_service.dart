import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/task_comment.dart';
import '../utils/logger.dart';

class CommentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get comments for a specific task
  Future<List<TaskComment>> getTaskComments(String taskId) async {
    try {
      final response = await _supabase
          .from('task_comments')
          .select('*')
          .eq('task_id', taskId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((comment) => TaskComment.fromJson(comment))
          .toList();
    } catch (e) {
      Log.error('Failed to get task comments: $e');
      return [];
    }
  }

  /// Add a comment to a task
  Future<TaskComment?> addComment(String taskId, String content) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      // Get user name
      final userResponse = await _supabase
          .from('usr')
          .select('name')
          .eq('id', user.id)
          .maybeSingle();

      final userName = userResponse?['name'] ?? 'Unknown User';

      final comment = TaskComment(
        id: const Uuid().v4(),
        taskId: taskId,
        userId: user.id,
        userName: userName,
        content: content,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _supabase.from('task_comments').insert(comment.toJson());
      
      Log.info('Comment added: ${comment.id} for task: $taskId');
      return comment;
    } catch (e) {
      Log.error('Failed to add comment: $e');
      return null;
    }
  }

  /// Update a comment
  Future<bool> updateComment(String commentId, String newContent) async {
    try {
      await _supabase
          .from('task_comments')
          .update({
            'content': newContent,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', commentId);

      Log.info('Comment updated: $commentId');
      return true;
    } catch (e) {
      Log.error('Failed to update comment: $e');
      return false;
    }
  }

  /// Delete a comment
  Future<bool> deleteComment(String commentId) async {
    try {
      await _supabase
          .from('task_comments')
          .delete()
          .eq('id', commentId);

      Log.info('Comment deleted: $commentId');
      return true;
    } catch (e) {
      Log.error('Failed to delete comment: $e');
      return false;
    }
  }

  /// Get comment count for a task
  Future<int> getCommentCount(String taskId) async {
    try {
      final response = await _supabase
          .from('task_comments')
          .select('id')
          .eq('task_id', taskId);

      return (response as List).length;
    } catch (e) {
      Log.error('Failed to get comment count: $e');
      return 0;
    }
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';
import '../utils/logger.dart';

/// Service for managing task handoffs between users
class HandoffService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Request a handoff for a task
  Future<void> requestHandoff(String taskId, String fromUserId, String toUserId) async {
    try {
      await _supabase.from('task_handoffs').insert({
        'task_id': taskId,
        'from_user_id': fromUserId,
        'to_user_id': toUserId,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      Log.error('Failed to request handoff: $e');
      rethrow;
    }
  }

  /// Accept a handoff request
  Future<void> acceptHandoff(String handoffId) async {
    try {
      await _supabase.from('task_handoffs').update({
        'status': 'accepted',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', handoffId);
    } catch (e) {
      Log.error('Failed to accept handoff: $e');
      rethrow;
    }
  }

  /// Decline a handoff request
  Future<void> declineHandoff(String handoffId) async {
    try {
      await _supabase.from('task_handoffs').update({
        'status': 'declined',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', handoffId);
    } catch (e) {
      Log.error('Failed to decline handoff: $e');
      rethrow;
    }
  }

  /// Get pending handoffs for a user
  Future<List<Map<String, dynamic>>> getPendingHandoffs(String userId) async {
    try {
      final response = await _supabase
          .from('task_handoffs')
          .select('*')
          .eq('to_user_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      
      return response as List<Map<String, dynamic>>;
    } catch (e) {
      Log.error('Failed to get pending handoffs: $e');
      return [];
    }
  }

  /// Get handoff stream for real-time updates
  // TODO: Fix stream implementation when Supabase stream API is stable
  Stream<List<Map<String, dynamic>>> getHandoffStream(String userId) {
    // Temporarily return empty stream to avoid compilation issues
    return Stream.value(<Map<String, dynamic>>[]);
  }
}

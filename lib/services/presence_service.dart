import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

/// Service for managing user presence and online status
class PresenceService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Update user's last seen timestamp
  Future<void> updateLastSeen(String userId) async {
    try {
      await _supabase.from('usr').update({
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      Log.error('Failed to update last seen: $e');
      // Don't rethrow as this is not critical
    }
  }

  /// Get user's online status
  Future<bool> isUserOnline(String userId) async {
    try {
      final response = await _supabase
          .from('usr')
          .select('last_seen')
          .eq('id', userId)
          .single();
      
      if (response['last_seen'] == null) return false;
      
      final lastSeen = DateTime.parse(response['last_seen'] as String);
      final now = DateTime.now();
      final difference = now.difference(lastSeen).inMinutes;
      
      // Consider user online if last seen within 5 minutes
      return difference < 5;
    } catch (e) {
      Log.error('Failed to check user online status: $e');
      return false;
    }
  }

  /// Get online status for multiple users
  Future<Map<String, bool>> getOnlineStatus(List<String> userIds) async {
    try {
      final response = await _supabase
          .from('usr')
          .select('id, last_seen')
          .inFilter('id', userIds);
      
      final now = DateTime.now();
      final result = <String, bool>{};
      
      for (final user in response) {
        final userId = user['id'] as String;
        final lastSeen = user['last_seen'] as String?;
        
        if (lastSeen == null) {
          result[userId] = false;
        } else {
          final lastSeenTime = DateTime.parse(lastSeen);
          final difference = now.difference(lastSeenTime).inMinutes;
          result[userId] = difference < 5;
        }
      }
      
      return result;
    } catch (e) {
      Log.error('Failed to get online status for users: $e');
      return {};
    }
  }

  /// Subscribe to presence changes
  Stream<Map<String, bool>> subscribeToPresence(List<String> userIds) {
    return _supabase
        .from('usr')
        .stream(primaryKey: ['id'])
        .inFilter('id', userIds)
        .map((response) {
          final now = DateTime.now();
          final result = <String, bool>{};
          
          for (final user in response) {
            final userId = user['id'] as String;
            final lastSeen = user['last_seen'] as String?;
            
            if (lastSeen == null) {
              result[userId] = false;
            } else {
              final lastSeenTime = DateTime.parse(lastSeen);
              final difference = now.difference(lastSeenTime).inMinutes;
              result[userId] = difference < 5;
            }
          }
          
          return result;
        });
  }

  /// Set user as online
  Future<void> setOnline(String userId) async {
    await updateLastSeen(userId);
  }

  /// Set user as offline
  Future<void> setOffline(String userId) async {
    try {
      await _supabase.from('usr').update({
        'last_seen': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      Log.error('Failed to set user offline: $e');
    }
  }
}

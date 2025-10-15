import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import 'dart:math';

/// Clean pairing service implementing the dyad-based approach from PAIRING.md
class CleanPairingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Pair up with another user using their pair code
  Future<Map<String, dynamic>> pairUpWithCode(String pairCode) async {
    try {
      Log.info('🔍 Attempting to pair with code: "$pairCode"');
      
      // Get current user ID
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      // First, find the user with this pair code
      Log.info('🔍 Searching for pair code: "$pairCode"');
      
      // Try exact match first
      final userResponse = await _supabase
          .from('usr')
          .select('id, name, pair_code')
          .eq('pair_code', pairCode)
          .maybeSingle();

      Log.info('🔍 User response: $userResponse');
      
      // If not found, try case-insensitive search
      if (userResponse == null) {
        Log.info('🔍 Trying case-insensitive search...');
        final caseInsensitiveResponse = await _supabase
            .from('usr')
            .select('id, name, pair_code')
            .ilike('pair_code', pairCode)
            .maybeSingle();
        
        Log.info('🔍 Case-insensitive response: $caseInsensitiveResponse');
        
        if (caseInsensitiveResponse != null) {
          Log.info('🔍 Found user with case-insensitive search!');
          // Use the case-insensitive result
          final partnerId = caseInsensitiveResponse['id'] as String;
          final partnerName = caseInsensitiveResponse['name'] ?? 'Partner';
          
          // Prevent self-pairing
          if (partnerId == currentUserId) {
            throw Exception('Cannot pair with yourself');
          }
          
          // Use the new dyad-based pairing function
          final pairId = await _supabase.rpc('fn_pair_up', params: {
            'partner_id': partnerId,
          });
          
          return {
            'status': 'paired',
            'message': 'Paired with $partnerName 🎉',
            'partner_name': partnerName,
            'pair_id': pairId,
          };
        }
      }

      if (userResponse == null) {
        // Let's also check what pair codes exist in the database
        final allUsers = await _supabase
            .from('usr')
            .select('id, name, pair_code')
            .not('pair_code', 'is', null);
        
        Log.info('🔍 All users with pair codes: $allUsers');
        
        // Let's also try a case-insensitive search
        final caseInsensitiveResponse = await _supabase
            .from('usr')
            .select('id, name, pair_code')
            .ilike('pair_code', pairCode)
            .maybeSingle();
        
        Log.info('🔍 Case-insensitive search result: $caseInsensitiveResponse');
        
        // Let's also check if there are any users at all
        final totalUsers = await _supabase
            .from('usr')
            .select('id, email, name, pair_code')
            .limit(10);
        
        Log.info('🔍 Total users in database: $totalUsers');
        
        throw Exception('Invalid pair code');
      }

      final partnerId = userResponse['id'] as String;
      final partnerName = userResponse['name'] ?? 'Partner';

      // Prevent self-pairing
      if (partnerId == currentUserId) {
        throw Exception('Cannot pair with yourself');
      }

      // Use the new dyad-based pairing function
      final pairId = await _supabase.rpc('fn_pair_up', params: {
        'partner_id': partnerId,
      });

      return {
        'status': 'paired',
        'message': 'Paired with $partnerName 🎉',
        'partner_name': partnerName,
        'pair_id': pairId,
      };
    } catch (e) {
      Log.error('Failed to pair up: $e');
      if (e.toString().contains('already paired')) {
        return {
          'status': 'error',
          'message': 'That user is already paired.',
        };
      }
      rethrow;
    }
  }

  /// Unpair from current partner
  Future<bool> unpair() async {
    try {
      await _supabase.rpc('fn_unpair');
      Log.info('Successfully unpaired');
      return true;
    } catch (e) {
      Log.error('Failed to unpair: $e');
      rethrow;
    }
  }

  /// Get current pair information
  Future<Map<String, dynamic>?> getCurrentPair() async {
    try {
      final response = await _supabase.rpc('fn_get_current_pair');
      
      if (response == null || response.isEmpty) {
        return null;
      }

      final pairInfo = response[0] as Map<String, dynamic>;
      return {
        'pair_id': pairInfo['pair_id'],
        'partner_id': pairInfo['partner_id'],
        'partner_name': pairInfo['partner_name'],
        'status': pairInfo['status'],
      };
    } catch (e) {
      Log.error('Failed to get current pair: $e');
      return null;
    }
  }

  /// Create a shared task
  Future<String?> createSharedTask(String title, {String? description, DateTime? dueDate}) async {
    try {
      final taskId = await _supabase.rpc('fn_create_shared_task', params: {
        'task_title': title,
        'task_description': description,
        'due_date': dueDate?.toIso8601String(),
      });

      return taskId as String?;
    } catch (e) {
      Log.error('Failed to create shared task: $e');
      rethrow;
    }
  }

  /// Get shared tasks for current user
  Future<List<Map<String, dynamic>>> getSharedTasks() async {
    try {
      final response = await _supabase
          .from('tasks')
          .select('''
            id,
            title,
            description,
            status,
            creator_id,
            owner_id,
            pair_id,
            due_date,
            urgent,
            created_at,
            updated_at,
            creator:creator_id(name),
            owner:owner_id(name)
          ''')
          .eq('scope', 'shared')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      Log.error('Failed to get shared tasks: $e');
      return [];
    }
  }

  /// Get personal tasks for current user
  Future<List<Map<String, dynamic>>> getPersonalTasks() async {
    try {
      final response = await _supabase
          .from('tasks')
          .select('''
            id,
            title,
            description,
            status,
            creator_id,
            owner_id,
            due_date,
            urgent,
            created_at,
            updated_at,
            creator:creator_id(name),
            owner:owner_id(name)
          ''')
          .eq('scope', 'personal')
          .eq('creator_id', _supabase.auth.currentUser?.id ?? '')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      Log.error('Failed to get personal tasks: $e');
      return [];
    }
  }

  /// Create a personal task
  Future<String?> createPersonalTask(String title, {String? description, DateTime? dueDate}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('tasks')
          .insert({
            'title': title,
            'description': description,
            'scope': 'personal',
            'creator_id': userId,
            'owner_id': userId,
            'due_date': dueDate?.toIso8601String(),
            'status': 'pending',
          })
          .select('id')
          .single();

      return response['id'] as String?;
    } catch (e) {
      Log.error('Failed to create personal task: $e');
      rethrow;
    }
  }

  /// Update task status
  Future<bool> updateTaskStatus(String taskId, String status) async {
    try {
      await _supabase
          .from('tasks')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId);

      return true;
    } catch (e) {
      Log.error('Failed to update task status: $e');
      return false;
    }
  }

  /// Claim a task
  Future<bool> claimTask(String taskId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('tasks')
          .update({
            'owner_id': userId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId);

      return true;
    } catch (e) {
      Log.error('Failed to claim task: $e');
      return false;
    }
  }

  /// Reclaim a task from another user
  Future<bool> reclaimTask(String taskId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Get current task to validate it can be reclaimed
      final task = await _supabase
          .from('tasks')
          .select('owner_id, scope, pair_id')
          .eq('id', taskId)
          .single();

      // Only allow reclaiming shared tasks that are currently claimed by someone else
      if (task['scope'] != 'shared' || task['owner_id'] == userId) {
        throw Exception('Task cannot be reclaimed');
      }

      // Verify user is part of the pair
      final pair = await getCurrentPair();
      if (pair == null || pair['pair_id'] != task['pair_id']) {
        throw Exception('You can only reclaim tasks from your current pair');
      }

      await _supabase
          .from('tasks')
          .update({
            'owner_id': userId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId);

      return true;
    } catch (e) {
      Log.error('Failed to reclaim task: $e');
      return false;
    }
  }

  /// Listen for pairing status changes
  RealtimeChannel listenToPairingStatus(String userId, Function(Map<String, dynamic>) onStatusChange) {
    return _supabase
        .channel('clean_pairing_status_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'pair',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_a',
            value: userId,
          ),
          callback: (payload) {
            if (payload != null) {
              final newRecord = payload.newRecord;
              if (newRecord != null) {
                onStatusChange(newRecord);
              }
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'pair',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_b',
            value: userId,
          ),
          callback: (payload) {
            if (payload != null) {
              final newRecord = payload.newRecord;
              if (newRecord != null) {
                onStatusChange(newRecord);
              }
            }
          },
        );
  }

  /// Listen for task changes
  RealtimeChannel listenToTaskChanges(Function(Map<String, dynamic>) onTaskChange) {
    return _supabase
        .channel('clean_task_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          callback: (payload) {
            if (payload != null) {
              final record = payload.newRecord ?? payload.oldRecord;
              if (record != null) {
                onTaskChange(record);
              }
            }
          },
        );
  }

  /// Generate a new pair code for the user
  Future<String> generatePairCode() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Generate a random 6-digit code
      final code = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();

      // Update the user's pair_code field
      await _supabase
          .from('usr')
          .update({
            'pair_code': code,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      return code;
    } catch (e) {
      Log.error('Failed to generate pair code: $e');
      rethrow;
    }
  }

  /// Apply migration to add pair codes to existing users
  Future<void> applyPairCodeMigration() async {
    try {
      Log.info('🔧 Applying pair code migration...');
      
      // Get all users without pair codes
      final usersWithoutCodes = await _supabase
          .from('usr')
          .select('id, email, name')
          .or('pair_code.is.null,pair_code.eq.')
          .limit(100);
      
      Log.info('🔧 Found ${usersWithoutCodes.length} users without pair codes');
      
      for (final user in usersWithoutCodes) {
        try {
          // Generate a unique pair code
          const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
          String? pairCode;
          bool isUnique = false;
          
          for (var attempt = 0; attempt < 10; attempt++) {
            pairCode = List.generate(8, (_) => chars[Random.secure().nextInt(chars.length)]).join();
            
            // Check if this code is unique
            final existing = await _supabase
                .from('usr')
                .select('id')
                .eq('pair_code', pairCode)
                .maybeSingle();
            
            if (existing == null) {
              isUnique = true;
              break;
            }
          }
          
          if (isUnique && pairCode != null) {
            // Update user with the new pair code
            await _supabase
                .from('usr')
                .update({'pair_code': pairCode})
                .eq('id', user['id']);
            
            Log.info('✅ Generated pair code $pairCode for user ${user['email']}');
          } else {
            Log.error('❌ Could not generate unique pair code for user ${user['email']}');
          }
        } catch (e) {
          Log.error('❌ Error updating user ${user['email']}: $e');
        }
      }
      
      Log.info('🔧 Pair code migration completed');
    } catch (e) {
      Log.error('❌ Error applying pair code migration: $e');
      rethrow;
    }
  }

  /// Debug method to check all users and their pair codes
  Future<void> debugCheckAllUsers() async {
    try {
      Log.info('🔍 DEBUG: Checking all users in database...');
      
      // Get all users
      final allUsers = await _supabase
          .from('usr')
          .select('id, email, name, pair_code')
          .limit(50);
      
      Log.info('🔍 DEBUG: Total users found: ${allUsers.length}');
      
      for (final user in allUsers) {
        Log.info('🔍 DEBUG: User - ID: ${user['id']}, Email: ${user['email']}, Name: ${user['name']}, Pair Code: ${user['pair_code']}');
      }
      
      // Check current user
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        Log.info('🔍 DEBUG: Current user ID: ${currentUser.id}');
        
        final currentUserData = await _supabase
            .from('usr')
            .select('id, email, name, pair_code')
            .eq('id', currentUser.id)
            .maybeSingle();
        
        Log.info('🔍 DEBUG: Current user data: $currentUserData');
      }
      
      // Test specific pair code lookup
      final testCodes = ['TQE6TW3M', 'T3CAR34M'];
      for (final code in testCodes) {
        Log.info('🔍 DEBUG: Testing lookup for code: $code');
        
        final exactMatch = await _supabase
            .from('usr')
            .select('id, email, name, pair_code')
            .eq('pair_code', code)
            .maybeSingle();
        
        Log.info('🔍 DEBUG: Exact match for $code: $exactMatch');
        
        final caseInsensitive = await _supabase
            .from('usr')
            .select('id, email, name, pair_code')
            .ilike('pair_code', code)
            .maybeSingle();
        
        Log.info('🔍 DEBUG: Case-insensitive match for $code: $caseInsensitive');
      }
      
    } catch (e) {
      Log.error('❌ DEBUG: Error checking users: $e');
    }
  }
}

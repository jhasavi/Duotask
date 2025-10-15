import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import 'frequent_partners_service.dart';

/// Service for managing user pairing functionality
class PairingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get pair information for a user
  Future<Map<String, dynamic>?> getPairInfo(String userId) async {
    try {
      print('Getting pair info for user: $userId');
      
      final response = await _supabase
          .from('usr')
          .select('paired_with, name')
          .eq('id', userId)
          .maybeSingle();

      print('User response: $response');

      if (response == null || response['paired_with'] == null) {
        print('No pairing found for user: $userId');
        return null;
      }

      final partnerId = response['paired_with'] as String;
      print('Partner ID: $partnerId');

      // Get partner's information
      final partnerResponse = await _supabase
          .from('usr')
          .select('name, last_seen')
          .eq('id', partnerId)
          .maybeSingle();

      print('Partner response: $partnerResponse');

      if (partnerResponse == null) {
        print('Partner not found: $partnerId');
        return null;
      }

      // Check if partner is online (last seen within 5 minutes)
      final lastSeen = partnerResponse['last_seen'] as String?;
      bool isOnline = false;
      if (lastSeen != null) {
        final lastSeenTime = DateTime.parse(lastSeen);
        final now = DateTime.now();
        isOnline = now.difference(lastSeenTime).inMinutes < 5;
      }

      final result = {
        'partner_id': partnerId,
        'partner_name': partnerResponse['name'] ?? 'Partner',
        'online': isOnline,
      };
      
      print('Pair info result: $result');
      return result;
    } catch (e) {
      Log.error('Failed to get pair info: $e');
      print('Error getting pair info: $e');
      return null;
    }
  }

  /// Request pairing with another user using a code
  Future<bool> requestPairing(String userId, String pairCode) async {
    try {
      // First, check if the pair code exists and is available
      final codeResponse = await _supabase
          .from('usr')
          .select('id, pair_code, pair_status, name')
          .eq('pair_code', pairCode)
          .maybeSingle();

      if (codeResponse == null) {
        throw Exception('Invalid pair code');
      }

      final targetUserId = codeResponse['id'] as String;
      if (targetUserId == userId) {
        throw Exception('Cannot pair with yourself');
      }

      // Check if already paired
      if (codeResponse['pair_status'] == 'paired') {
        throw Exception('User is already paired');
      }

      // Check if this is a previous partner (automatic pairing)
      final frequentPartnersService = FrequentPartnersService();
      final frequentPartners = await frequentPartnersService.getFrequentPartners(userId);
      final isPreviousPartner = frequentPartners.any((partner) => partner.partnerId == targetUserId);

      if (isPreviousPartner) {
        // Automatic pairing for previous partners
        await _supabase.rpc('pair_users', params: {
          'p_user_id': userId,
          'p_partner_id': targetUserId,
        });

        // Update partner history
        final partnerName = codeResponse['name'] ?? 'Partner';
        await frequentPartnersService.addPartnerHistory(userId, targetUserId, partnerName);

        // Restore shared tasks from previous pairing
        await _restoreSharedTasks(userId, targetUserId);

        Log.info('Automatic re-pairing completed: $userId -> $targetUserId ($partnerName)');
        return true;
      }

      // Regular pairing request for new partners
      await _supabase
          .from('usr')
          .update({
            'pair_request_from': userId,
            'pair_status': 'pending',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', targetUserId);

      return true;
    } catch (e) {
      Log.error('Failed to request pairing: $e');
      rethrow;
    }
  }

  /// Accept a pairing request
  Future<bool> acceptPairing(String requestId, String userId) async {
    try {
      // Get the request details from the user's pair_request_from field
      final userResponse = await _supabase
          .from('usr')
          .select('pair_request_from, pair_status')
          .eq('id', userId)
          .eq('pair_status', 'pending')
          .maybeSingle();

      if (userResponse == null || userResponse['pair_request_from'] == null) {
        throw Exception('No pending pairing request found');
      }

      final fromUserId = userResponse['pair_request_from'] as String;

      // Update both users to be paired
      await _supabase.from('usr').update({
        'paired_with': fromUserId,
        'pair_status': 'paired',
        'pair_request_from': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      await _supabase.from('usr').update({
        'paired_with': userId,
        'pair_status': 'paired',
        'pair_request_from': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', fromUserId);

      return true;
    } catch (e) {
      Log.error('Failed to accept pairing: $e');
      rethrow;
    }
  }

  /// Decline a pairing request
  Future<bool> declinePairing(String requestId, String userId) async {
    try {
      // Verify the user is the intended recipient
      final requestResponse = await _supabase
          .from('pair_requests')
          .select('to_user_id')
          .eq('id', requestId)
          .eq('status', 'pending')
          .maybeSingle();

      if (requestResponse == null) {
        throw Exception('Pairing request not found or already processed');
      }

      final toUserId = requestResponse['to_user_id'] as String;
      if (toUserId != userId) {
        throw Exception('Not authorized to decline this request');
      }

      // Mark the request as declined
      await _supabase.from('pair_requests').update({
        'status': 'declined',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      return true;
    } catch (e) {
      Log.error('Failed to decline pairing: $e');
      rethrow;
    }
  }

  /// Unpair from current partner
  Future<bool> unpairUser(String userId) async {
    try {
      // Get current pairing info
      final userResponse = await _supabase
          .from('usr')
          .select('paired_with')
          .eq('id', userId)
          .maybeSingle();

      if (userResponse == null || userResponse['paired_with'] == null) {
        return false; // Not paired
      }

      final partnerId = userResponse['paired_with'] as String;

      // Update partner history before unpairing to maintain the relationship for future re-pairing
      try {
        final frequentPartnersService = FrequentPartnersService();
        
        // Get partner names before unpairing
        final userResponse = await _supabase
            .from('usr')
            .select('name')
            .eq('id', userId)
            .maybeSingle();
        final partnerResponse = await _supabase
            .from('usr')
            .select('name')
            .eq('id', partnerId)
            .maybeSingle();
            
        final userName = userResponse?['name'] ?? 'User';
        final partnerName = partnerResponse?['name'] ?? 'Partner';
        
        // Update history for both users
        await frequentPartnersService.updatePartnerHistoryOnUnpair(userId, partnerId, partnerName);
        await frequentPartnersService.updatePartnerHistoryOnUnpair(partnerId, userId, userName);
      } catch (e) {
        Log.warn('Failed to update partner history on unpair: $e');
        // Continue with unpairing even if history update fails
      }

      // Create unpairing notification for the partner
      await _createUnpairingNotification(partnerId, userId);

      // Remove pairing from both users atomically
      await _supabase.from('usr').update({
        'paired_with': null,
        'pair_status': null,
        'pair_request_from': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).or('id.eq.$userId,id.eq.$partnerId');

      Log.info('Successfully unpaired users: $userId and $partnerId');
      return true;
    } catch (e) {
      Log.error('Failed to unpair: $e');
      rethrow;
    }
  }

  /// Generate a new pair code for the user
  Future<String> generatePairCode(String userId) async {
    try {
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

  /// Pair with another user
  Future<bool> pairWithUser(String userId, String partnerId) async {
    try {
      // Update both users to be paired atomically
      await _supabase.from('usr').update({
        'paired_with': partnerId,
        'pair_status': 'paired',
        'updated_at': DateTime.now().toIso8601String(),
      }).or('id.eq.$userId,id.eq.$partnerId');

      Log.info('Successfully paired users: $userId and $partnerId');
      return true;
    } catch (e) {
      Log.error('Failed to pair users: $e');
      rethrow;
    }
  }

  /// Create unpairing notification
  Future<void> _createUnpairingNotification(String partnerId, String initiatorId) async {
    try {
      // Get initiator's name
      final initiatorResponse = await _supabase
          .from('usr')
          .select('name')
          .eq('id', initiatorId)
          .maybeSingle();
      
      final initiatorName = initiatorResponse?['name'] ?? 'Partner';

      // Create notification record (you can extend this for push notifications later)
      await _supabase.from('notifications').insert({
        'user_id': partnerId,
        'type': 'unpairing',
        'title': 'Pairing Ended',
        'message': '$initiatorName has ended the pairing',
        'created_at': DateTime.now().toIso8601String(),
        'read': false,
      });
    } catch (e) {
      Log.error('Failed to create unpairing notification: $e');
    }
  }

  /// Listen for pairing status changes
  RealtimeChannel listenToPairingStatus(String userId, Function(Map<String, dynamic>) onStatusChange) {
    return _supabase
        .channel('pairing_status_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'usr',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
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

  /// Get pending pairing requests for a user
  Future<List<Map<String, dynamic>>> getPendingRequests(String userId) async {
    try {
      // Check if current user has a pending request
      final userResponse = await _supabase
          .from('usr')
          .select('pair_request_from, pair_status')
          .eq('id', userId)
          .eq('pair_status', 'pending')
          .maybeSingle();

      if (userResponse == null || userResponse['pair_request_from'] == null) {
        return [];
      }

      // Get the requesting user's information
      final fromUserId = userResponse['pair_request_from'] as String;
      final fromUserResponse = await _supabase
          .from('usr')
          .select('id, name, created_at')
          .eq('id', fromUserId)
          .maybeSingle();

      if (fromUserResponse == null) {
        return [];
      }

      return [{
        'id': fromUserId, // Use the from_user_id as the request ID
        'from_user_id': fromUserId,
        'from_user_name': fromUserResponse['name'] ?? 'Unknown User',
        'created_at': fromUserResponse['created_at'],
      }];
    } catch (e) {
      Log.error('Failed to get pending requests: $e');
      return [];
    }
  }

  /// Restore shared tasks when re-pairing with a previous partner
  Future<void> _restoreSharedTasks(String userId, String partnerId) async {
    try {
      // Get shared tasks from previous pairing using task_pairing_history
      final sharedTasks = await _supabase
          .rpc('get_tasks_for_pairing', params: {
            'p_user_id': userId,
            'p_partner_id': partnerId,
          });

      if (sharedTasks.isNotEmpty) {
        Log.info('Restoring ${sharedTasks.length} shared tasks for pairing $userId <-> $partnerId');
        
        // Update pair_id for all shared tasks to make them visible again
        for (final task in sharedTasks) {
          await _supabase
              .from('tasks')
              .update({
                'pair_id': partnerId,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', task['task_id']);
        }
      }
    } catch (e) {
      Log.error('Failed to restore shared tasks: $e');
      // Don't rethrow - task restoration failure shouldn't break pairing
    }
  }
}


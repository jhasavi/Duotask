import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import 'frequent_partners_service.dart';

/// Enhanced pairing service with request queue and notifications
class EnhancedPairingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Request pairing with another user (handles queuing if user is already paired)
  Future<Map<String, dynamic>> requestPairing(String userId, String pairCode) async {
    try {
      // First, check if the pair code exists
      final codeResponse = await _supabase
          .from('usr')
          .select('id, pair_code, pair_status, name, paired_with')
          .eq('pair_code', pairCode)
          .maybeSingle();

      if (codeResponse == null) {
        throw Exception('Invalid pair code');
      }

      final targetUserId = codeResponse['id'] as String;
      if (targetUserId == userId) {
        throw Exception('Cannot pair with yourself');
      }

      final targetUserStatus = codeResponse['pair_status'] as String?;
      final targetUserPairedWith = codeResponse['paired_with'] as String?;

      // If target user is already paired
      if (targetUserStatus == 'paired' && targetUserPairedWith != null) {
        // Create a pairing request instead
        await _createPairingRequest(userId, targetUserId);
        
        return {
          'status': 'request_sent',
          'message': 'User is currently paired. Your request has been sent and will be reviewed when they become available.',
          'target_user_name': codeResponse['name'] ?? 'Partner'
        };
      }

      // If target user is available, proceed with normal pairing
      if (targetUserStatus == 'unpaired' || targetUserStatus == null) {
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

          return {
            'status': 'paired',
            'message': 'Successfully paired with ${partnerName}!',
            'partner_name': partnerName
          };
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

        return {
          'status': 'request_sent',
          'message': 'Pairing request sent!',
          'target_user_name': codeResponse['name'] ?? 'Partner'
        };
      }

      throw Exception('User is not available for pairing');
    } catch (e) {
      Log.error('Failed to request pairing: $e');
      rethrow;
    }
  }

  /// Create a pairing request for when user is already paired
  Future<void> _createPairingRequest(String fromUserId, String toUserId) async {
    try {
      await _supabase.from('pairing_requests').insert({
        'from_user_id': fromUserId,
        'to_user_id': toUserId,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      });
    } catch (e) {
      Log.error('Failed to create pairing request: $e');
      rethrow;
    }
  }

  /// Get pending pairing requests for a user
  Future<List<Map<String, dynamic>>> getPendingPairingRequests(String userId) async {
    try {
      final response = await _supabase
          .from('pairing_requests')
          .select('''
            id,
            from_user_id,
            to_user_id,
            status,
            created_at,
            expires_at,
            from_user:from_user_id(id, name),
            to_user:to_user_id(id, name)
          ''')
          .or('from_user_id.eq.$userId,to_user_id.eq.$userId')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      Log.error('Failed to get pending pairing requests: $e');
      return [];
    }
  }

  /// Accept a pairing request
  Future<bool> acceptPairingRequest(String requestId, String userId) async {
    try {
      // Get the request details
      final requestResponse = await _supabase
          .from('pairing_requests')
          .select('from_user_id, to_user_id, status')
          .eq('id', requestId)
          .eq('status', 'pending')
          .maybeSingle();

      if (requestResponse == null) {
        throw Exception('Pairing request not found or already processed');
      }

      final fromUserId = requestResponse['from_user_id'] as String;
      final toUserId = requestResponse['to_user_id'] as String;

      // Verify the user is the intended recipient
      if (toUserId != userId) {
        throw Exception('Not authorized to accept this request');
      }

      // Update the request status
      await _supabase.from('pairing_requests').update({
        'status': 'accepted',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      // Pair the users
      await _supabase.rpc('pair_users', params: {
        'p_user_id': fromUserId,
        'p_partner_id': toUserId,
      });

      // Update partner history
      final frequentPartnersService = FrequentPartnersService();
      final fromUserResponse = await _supabase
          .from('usr')
          .select('name')
          .eq('id', fromUserId)
          .maybeSingle();
      final toUserResponse = await _supabase
          .from('usr')
          .select('name')
          .eq('id', toUserId)
          .maybeSingle();

      final fromUserName = fromUserResponse?['name'] ?? 'Partner';
      final toUserName = toUserResponse?['name'] ?? 'Partner';

      await frequentPartnersService.addPartnerHistory(fromUserId, toUserId, toUserName);
      await frequentPartnersService.addPartnerHistory(toUserId, fromUserId, fromUserName);

      return true;
    } catch (e) {
      Log.error('Failed to accept pairing request: $e');
      rethrow;
    }
  }

  /// Decline a pairing request
  Future<bool> declinePairingRequest(String requestId, String userId) async {
    try {
      final requestResponse = await _supabase
          .from('pairing_requests')
          .select('to_user_id, status')
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

      await _supabase.from('pairing_requests').update({
        'status': 'declined',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      return true;
    } catch (e) {
      Log.error('Failed to decline pairing request: $e');
      rethrow;
    }
  }

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

  /// Enhanced unpairing with notifications
  Future<bool> unpairUser(String userId) async {
    try {
      // Get current partner info
      final userResponse = await _supabase
          .from('usr')
          .select('paired_with, name')
          .eq('id', userId)
          .maybeSingle();

      if (userResponse == null || userResponse['paired_with'] == null) {
        throw Exception('User is not currently paired');
      }

      final partnerId = userResponse['paired_with'] as String;
      final userName = userResponse['name'] ?? 'Partner';

      // Update partner history before unpairing
      try {
        final frequentPartnersService = FrequentPartnersService();
        final partnerResponse = await _supabase
            .from('usr')
            .select('name')
            .eq('id', partnerId)
            .maybeSingle();
        final partnerName = partnerResponse?['name'] ?? 'Partner';
        
        await frequentPartnersService.updatePartnerHistoryOnUnpair(userId, partnerId, partnerName);
        await frequentPartnersService.updatePartnerHistoryOnUnpair(partnerId, userId, userName);
      } catch (e) {
        Log.warn('Failed to update partner history on unpair: $e');
      }

      // Create unpairing notification for the partner
      await _createUnpairingNotification(partnerId, userId, userName);

      // Remove pairing from both users atomically
      await _supabase.from('usr').update({
        'paired_with': null,
        'pair_status': 'unpaired',
        'pair_request_from': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).or('id.eq.$userId,id.eq.$partnerId');

      // Check for pending pairing requests and notify users
      await _checkAndNotifyPendingRequests(userId);
      await _checkAndNotifyPendingRequests(partnerId);

      Log.info('Successfully unpaired users: $userId and $partnerId');
      return true;
    } catch (e) {
      Log.error('Failed to unpair: $e');
      rethrow;
    }
  }

  /// Create unpairing notification
  Future<void> _createUnpairingNotification(String partnerId, String initiatorId, String initiatorName) async {
    try {
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

  /// Check for pending requests and notify users
  Future<void> _checkAndNotifyPendingRequests(String userId) async {
    try {
      final pendingRequests = await getPendingPairingRequests(userId);
      
      for (final request in pendingRequests) {
        final fromUserId = request['from_user_id'] as String;
        final fromUserName = request['from_user']?['name'] ?? 'Someone';
        
        await _supabase.from('notifications').insert({
          'user_id': userId,
          'type': 'pairing_request',
          'title': 'New Pairing Request',
          'message': '$fromUserName wants to pair with you',
          'created_at': DateTime.now().toIso8601String(),
          'read': false,
        });
      }
    } catch (e) {
      Log.error('Failed to check pending requests: $e');
    }
  }

  /// Restore shared tasks when re-pairing with a previous partner
  Future<void> _restoreSharedTasks(String userId, String partnerId) async {
    try {
      final sharedTasks = await _supabase
          .rpc('get_tasks_for_pairing', params: {
            'p_user_id': userId,
            'p_partner_id': partnerId,
          });

      if (sharedTasks.isNotEmpty) {
        Log.info('Restoring ${sharedTasks.length} shared tasks for pairing $userId <-> $partnerId');
        
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
    }
  }

  /// Listen for pairing status changes with enhanced notifications
  RealtimeChannel listenToPairingStatus(String userId, Function(Map<String, dynamic>) onStatusChange) {
    return _supabase
        .channel('enhanced_pairing_status_$userId')
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
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'pairing_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'to_user_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload != null) {
              // Handle new pairing request notification
              Log.info('New pairing request received');
            }
          },
        );
  }
}

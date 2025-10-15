import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

/// Partner history entry
class PartnerHistoryEntry {
  final String partnerId;
  final String partnerName;
  final DateTime lastPairedAt;
  final int pairingCount;
  final bool isFavorite;

  PartnerHistoryEntry({
    required this.partnerId,
    required this.partnerName,
    required this.lastPairedAt,
    required this.pairingCount,
    required this.isFavorite,
  });

  factory PartnerHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PartnerHistoryEntry(
      partnerId: json['partner_id'] as String,
      partnerName: json['partner_name'] as String,
      lastPairedAt: DateTime.parse(json['last_paired_at'] as String),
      pairingCount: json['pairing_count'] as int,
      isFavorite: json['is_favorite'] as bool,
    );
  }
}

/// Service for managing frequent partners and partner history
class FrequentPartnersService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get frequent partners for a user
  Future<List<PartnerHistoryEntry>> getFrequentPartners(String userId) async {
    try {
      final response = await _supabase
          .rpc('get_frequent_partners', params: {'p_user_id': userId});

      if (response == null) {
        return [];
      }

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((item) => PartnerHistoryEntry.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Log.error('Failed to get frequent partners: $e');
      return [];
    }
  }

  /// Add or update partner history
  Future<void> addPartnerHistory(String userId, String partnerId, String partnerName) async {
    try {
      await _supabase.rpc('add_partner_history', params: {
        'p_user_id': userId,
        'p_partner_id': partnerId,
        'p_partner_name': partnerName,
      });
      
      Log.info('Partner history updated: $userId -> $partnerId ($partnerName)');
    } catch (e) {
      Log.error('Failed to add partner history: $e');
    }
  }

  /// Update partner history when unpairing (maintains history for future re-pairing)
  Future<void> updatePartnerHistoryOnUnpair(String userId, String partnerId, String partnerName) async {
    try {
      // Update the last_paired_at timestamp to now (when they unpaired)
      // This ensures they appear in recent partners for future re-pairing
      await _supabase.rpc('update_partner_history_on_unpair', params: {
        'p_user_id': userId,
        'p_partner_id': partnerId,
        'p_partner_name': partnerName,
      });
      
      Log.info('Partner history updated on unpair: $userId -> $partnerId ($partnerName)');
    } catch (e) {
      Log.error('Failed to update partner history on unpair: $e');
      // Fallback: try to add regular history if the specific function doesn't exist
      await addPartnerHistory(userId, partnerId, partnerName);
    }
  }

  /// Toggle favorite status for a partner
  Future<bool> togglePartnerFavorite(String userId, String partnerId) async {
    try {
      final response = await _supabase.rpc('toggle_partner_favorite', params: {
        'p_user_id': userId,
        'p_partner_id': partnerId,
      });

      final isFavorite = response as bool;
      Log.info('Partner favorite toggled: $userId -> $partnerId = $isFavorite');
      return isFavorite;
    } catch (e) {
      Log.error('Failed to toggle partner favorite: $e');
      return false;
    }
  }

  /// Quick re-pair with a frequent partner (automatic, no confirmation needed)
  Future<bool> quickRePair(String userId, String partnerId) async {
    try {
      // Check if partner is available for pairing
      final partnerResponse = await _supabase
          .from('usr')
          .select('paired_with, pair_status, name')
          .eq('id', partnerId)
          .maybeSingle();

      if (partnerResponse == null) {
        throw Exception('Partner not found');
      }

      final partnerPairedWith = partnerResponse['paired_with'];
      final partnerStatus = partnerResponse['pair_status'];
      final partnerName = partnerResponse['name'] ?? 'Partner';

      // Check if partner is already paired
      if (partnerPairedWith != null) {
        throw Exception('Partner is already paired with someone else');
      }

      // Check if partner has pending requests
      if (partnerStatus == 'pending') {
        throw Exception('Partner has a pending pairing request');
      }

      // Direct pairing without confirmation (since they've paired before)
      await _supabase.rpc('pair_users', params: {
        'p_user_id': userId,
        'p_partner_id': partnerId,
      });

      // Update partner history
      await addPartnerHistory(userId, partnerId, partnerName);

      Log.info('Quick re-pair completed: $userId -> $partnerId ($partnerName)');
      return true;
    } catch (e) {
      Log.error('Failed to quick re-pair: $e');
      rethrow;
    }
  }

  /// Get partner suggestions based on usage patterns
  Future<List<PartnerHistoryEntry>> getPartnerSuggestions(String userId) async {
    try {
      final frequentPartners = await getFrequentPartners(userId);
      
      // Filter out partners who are currently paired with someone else
      final suggestions = <PartnerHistoryEntry>[];
      
      for (final partner in frequentPartners) {
        try {
          final partnerResponse = await _supabase
              .from('usr')
              .select('paired_with, pair_status')
              .eq('id', partner.partnerId)
              .maybeSingle();

          if (partnerResponse != null) {
            final partnerPairedWith = partnerResponse['paired_with'];
            final partnerStatus = partnerResponse['pair_status'];

            // Suggest partners who are available
            if (partnerPairedWith == null && partnerStatus != 'pending') {
              suggestions.add(partner);
            }
          }
        } catch (e) {
          // Skip this partner if there's an error
          continue;
        }
      }

      return suggestions;
    } catch (e) {
      Log.error('Failed to get partner suggestions: $e');
      return [];
    }
  }

  /// Remove partner from history
  Future<void> removePartnerFromHistory(String userId, String partnerId) async {
    try {
      await _supabase
          .from('partner_history')
          .delete()
          .eq('user_id', userId)
          .eq('partner_id', partnerId);

      Log.info('Partner removed from history: $userId -> $partnerId');
    } catch (e) {
      Log.error('Failed to remove partner from history: $e');
    }
  }

  /// Get partner history statistics
  Future<Map<String, dynamic>> getPartnerStats(String userId) async {
    try {
      final frequentPartners = await getFrequentPartners(userId);
      
      int totalPartners = frequentPartners.length;
      int favoritePartners = frequentPartners.where((p) => p.isFavorite).length;
      int totalPairings = frequentPartners.fold(0, (sum, p) => sum + p.pairingCount);
      
      PartnerHistoryEntry? mostFrequentPartner;
      if (frequentPartners.isNotEmpty) {
        mostFrequentPartner = frequentPartners.reduce((a, b) => 
          a.pairingCount > b.pairingCount ? a : b);
      }

      return {
        'total_partners': totalPartners,
        'favorite_partners': favoritePartners,
        'total_pairings': totalPairings,
        'most_frequent_partner': mostFrequentPartner?.partnerName,
        'most_frequent_pairings': mostFrequentPartner?.pairingCount ?? 0,
      };
    } catch (e) {
      Log.error('Failed to get partner stats: $e');
      return {
        'total_partners': 0,
        'favorite_partners': 0,
        'total_pairings': 0,
        'most_frequent_partner': null,
        'most_frequent_pairings': 0,
      };
    }
  }
}

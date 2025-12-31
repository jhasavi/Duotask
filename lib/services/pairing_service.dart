import 'dart:math';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/pairing.dart';
import '../models/user.dart';

class PairingService extends ChangeNotifier {
  final SupabaseClient _supabase;
  Pairing? _currentPairing;
  AppUser? _partner;
  bool _isLoading = false;
  String? _errorMessage;
  RealtimeChannel? _pairingChannel;

  PairingService(this._supabase);

  Pairing? get currentPairing => _currentPairing;
  AppUser? get partner => _partner;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isPaired => _currentPairing?.isActive ?? false;

  Future<void> checkPairingStatus(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      // Check if user has an active pairing
      final response = await _supabase
          .from('pairings')
          .select()
          .or('requester_id.eq.$userId,recipient_id.eq.$userId')
          .eq('status', PairingStatus.active.name)
          .maybeSingle();

      if (response != null) {
        _currentPairing = Pairing.fromJson(response);
        await _loadPartner(userId);
      }

      _setLoading(false);
      _setupRealtimeSubscription(userId);
    } on SocketException {
      _setError('No internet connection. Please check your network.');
      _setLoading(false);
    } on PostgrestException catch (e) {
      _setError('Failed to check pairing status: ${e.message}');
      _setLoading(false);
    } catch (e) {
      _setError('Failed to check pairing status. Please try again.');
      if (kDebugMode) print('Check pairing error: $e');
      _setLoading(false);
    }
  }

  Future<void> _loadPartner(String userId) async {
    try {
      if (_currentPairing == null) return;

      final partnerId = _currentPairing!.requesterId == userId
          ? _currentPairing!.recipientId
          : _currentPairing!.requesterId;

      if (partnerId == null) return;

      final response = await _supabase
          .from('users')
          .select()
          .eq('id', partnerId)
          .single();

      _partner = AppUser.fromJson(response);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading partner: $e');
      }
    }
  }

  void _setupRealtimeSubscription(String userId) {
    _pairingChannel?.unsubscribe();

    _pairingChannel = _supabase
        .channel('pairings:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pairings',
          callback: (payload) {
            _handleRealtimeUpdate(payload, userId);
          },
        )
        .subscribe();
  }

  void _handleRealtimeUpdate(PostgresChangePayload payload, String userId) {
    final eventType = payload.eventType;
    final newRecord = payload.newRecord;

    if (eventType == PostgresChangeEvent.update ||
        eventType == PostgresChangeEvent.insert) {
      if (newRecord != null) {
        final pairing = Pairing.fromJson(newRecord);
        if (pairing.isActive) {
          _currentPairing = pairing;
          _loadPartner(userId);
        }
      }
    } else if (eventType == PostgresChangeEvent.delete) {
      _currentPairing = null;
      _partner = null;
      notifyListeners();
    }
  }

  String _generatePairingCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(
      8,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  Future<String?> getMyPendingPairingCode(String userId) async {
    try {
      final response = await _supabase
          .from('pairings')
          .select('pairing_code')
          .eq('requester_id', userId)
          .eq('status', PairingStatus.pending.name)
          .maybeSingle();

      if (response != null && response['pairing_code'] != null) {
        return response['pairing_code'] as String;
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Error getting pending pairing code: $e');
      return null;
    }
  }

  Future<String?> createPairingCode(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      // Cancel any existing pending pairing requests by this user
      await _supabase
          .from('pairings')
          .update({'status': PairingStatus.cancelled.name})
          .eq('requester_id', userId)
          .eq('status', PairingStatus.pending.name);

      final pairingCode = _generatePairingCode();
      final pairingId = const Uuid().v4();

      final pairingData = {
        'id': pairingId,
        'requester_id': userId,
        'pairing_code': pairingCode,
        'status': PairingStatus.pending.name,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('pairings').insert(pairingData);

      // Update user's pairing code
      await _supabase
          .from('users')
          .update({'pairing_code': pairingCode}).eq('id', userId);

      _setLoading(false);
      return pairingCode;
    } on SocketException {
      _setError('No internet connection. Cannot create pairing code.');
      _setLoading(false);
      return null;
    } on PostgrestException catch (e) {
      _setError('Failed to create pairing code: ${e.message}');
      if (kDebugMode) print('PostgrestException: ${e.message}');
      if (kDebugMode) print('Details: ${e.details}');
      _setLoading(false);
      return null;
    } catch (e) {
      _setError('Failed to create pairing code. Please try again.');
      if (kDebugMode) print('Create pairing code error: $e');
      _setLoading(false);
      return null;
    }
  }

  Future<bool> acceptPairingCode(String userId, String pairingCode) async {
    _setLoading(true);
    _clearError();

    try {
      if (kDebugMode) print('Accepting pairing code: $pairingCode');
      
      // Find the pairing request
      final response = await _supabase
          .from('pairings')
          .select()
          .eq('pairing_code', pairingCode.toUpperCase())
          .eq('status', PairingStatus.pending.name)
          .maybeSingle();

      if (kDebugMode) print('Pairing response: $response');

      if (response == null) {
        _setError('Invalid or expired pairing code');
        if (kDebugMode) print('No pairing found with code: $pairingCode');
        _setLoading(false);
        return false;
      }

      final pairing = Pairing.fromJson(response);

      // Can't pair with yourself
      if (pairing.requesterId == userId) {
        _setError('Cannot pair with yourself');
        _setLoading(false);
        return false;
      }

      if (kDebugMode) print('Updating pairing to active...');

      // Update pairing to active
      await _supabase.from('pairings').update({
        'recipient_id': userId,
        'status': PairingStatus.active.name,
        'accepted_at': DateTime.now().toIso8601String(),
      }).eq('id', pairing.id);

      if (kDebugMode) print('Pairing updated successfully');

      // Load updated pairing status
      await checkPairingStatus(userId);

      _setLoading(false);
      return true;
    } on SocketException {
      _setError('No internet connection. Cannot accept pairing.');
      _setLoading(false);
      return false;
    } on PostgrestException catch (e) {
      _setError('Failed to accept pairing: ${e.message}');
      if (kDebugMode) print('PostgrestException: ${e.message}');
      if (kDebugMode) print('Details: ${e.details}');
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to accept pairing. Please try again.');
      if (kDebugMode) print('Accept pairing error: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> unpair(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      if (_currentPairing == null) {
        _setError('No active pairing to remove');
        _setLoading(false);
        return false;
      }

      // Update pairing status to cancelled
      await _supabase.from('pairings').update({
        'status': PairingStatus.cancelled.name,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _currentPairing!.id);

      // Clear pairing info from both users
      final partnerId = _currentPairing!.requesterId == userId
          ? _currentPairing!.recipientId
          : _currentPairing!.requesterId;

      await _supabase.from('users').update({
        'paired_with_id': null,
        'paired_with_name': null,
      }).eq('id', userId);

      if (partnerId != null) {
        await _supabase.from('users').update({
          'paired_with_id': null,
          'paired_with_name': null,
        }).eq('id', partnerId);
      }

      _currentPairing = null;
      _partner = null;
      _setLoading(false);
      notifyListeners();
      return true;
    } on SocketException {
      _setError('No internet connection. Cannot unpair.');
      _setLoading(false);
      return false;
    } on PostgrestException catch (e) {
      _setError('Failed to unpair: ${e.message}');
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to unpair. Please try again.');
      if (kDebugMode) print('Unpair error: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<List<Pairing>> getPairingHistory(String userId) async {
    try {
      final response = await _supabase
          .from('pairings')
          .select()
          .or('requester_id.eq.$userId,recipient_id.eq.$userId')
          .order('created_at', ascending: false);

      return (response as List).map((json) => Pairing.fromJson(json)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading pairing history: $e');
      }
      return [];
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  @override
  void dispose() {
    _pairingChannel?.unsubscribe();
    super.dispose();
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Nudge {
  final String id;
  final String pairId;
  final String taskId;
  final String fromUserId;
  final String toUserId;
  final String message;
  final bool read;
  final DateTime createdAt;

  Nudge({
    required this.id,
    required this.pairId,
    required this.taskId,
    required this.fromUserId,
    required this.toUserId,
    required this.message,
    required this.read,
    required this.createdAt,
  });

  factory Nudge.fromJson(Map<String, dynamic> json) {
    return Nudge(
      id: json['id'] as String,
      pairId: json['pair_id'] as String,
      taskId: json['task_id'] as String,
      fromUserId: json['from_user_id'] as String,
      toUserId: json['to_user_id'] as String,
      message: json['message'] as String,
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pair_id': pairId,
      'task_id': taskId,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'message': message,
      'read': read,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class NudgeService extends ChangeNotifier {
  final SupabaseClient _supabase;
  List<Nudge> _nudges = [];
  bool _isLoading = false;
  String? _errorMessage;
  RealtimeChannel? _nudgeChannel;

  NudgeService(this._supabase);

  List<Nudge> get nudges => _nudges;
  List<Nudge> get unreadNudges => _nudges.where((n) => !n.read).toList();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get unreadCount => unreadNudges.length;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  Future<void> loadNudges(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _supabase
          .from('nudges')
          .select()
          .eq('to_user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      _nudges = (response as List).map((json) => Nudge.fromJson(json)).toList();
      _setLoading(false);
      _setupRealtimeSubscription(userId);
    } on SocketException {
      _setError('No internet connection');
      _setLoading(false);
    } on PostgrestException catch (e) {
      _setError('Failed to load nudges: ${e.message}');
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load nudges');
      if (kDebugMode) print('Load nudges error: $e');
      _setLoading(false);
    }
  }

  void _setupRealtimeSubscription(String userId) {
    _nudgeChannel?.unsubscribe();

    _nudgeChannel = _supabase
        .channel('nudges:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'nudges',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'to_user_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord != null) {
              final nudge = Nudge.fromJson(payload.newRecord!);
              _nudges.insert(0, nudge);
              notifyListeners();
            }
          },
        )
        .subscribe();
  }

  Future<bool> sendNudge({
    required String pairId,
    required String taskId,
    required String taskTitle,
    required String fromUserId,
    required String fromUserName,
    required String toUserId,
  }) async {
    _clearError();

    try {
      final message = '$fromUserName nudged you about "$taskTitle"';
      
      final nudgeData = {
        'pair_id': pairId,
        'task_id': taskId,
        'from_user_id': fromUserId,
        'to_user_id': toUserId,
        'message': message,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('nudges').insert(nudgeData);
      return true;
    } on SocketException {
      _setError('No internet connection');
      return false;
    } on PostgrestException catch (e) {
      _setError('Failed to send nudge: ${e.message}');
      return false;
    } catch (e) {
      _setError('Failed to send nudge');
      if (kDebugMode) print('Send nudge error: $e');
      return false;
    }
  }

  Future<bool> markAsRead(String nudgeId) async {
    try {
      await _supabase
          .from('nudges')
          .update({'read': true})
          .eq('id', nudgeId);

      final index = _nudges.indexWhere((n) => n.id == nudgeId);
      if (index != -1) {
        _nudges[index] = Nudge.fromJson({
          ..._nudges[index].toJson(),
          'read': true,
        });
        notifyListeners();
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('Mark nudge as read error: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from('nudges')
          .update({'read': true})
          .eq('to_user_id', userId)
          .eq('read', false);

      for (var i = 0; i < _nudges.length; i++) {
        if (!_nudges[i].read) {
          _nudges[i] = Nudge.fromJson({
            ..._nudges[i].toJson(),
            'read': true,
          });
        }
      }
      notifyListeners();

      return true;
    } catch (e) {
      if (kDebugMode) print('Mark all nudges as read error: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _nudgeChannel?.unsubscribe();
    super.dispose();
  }
}

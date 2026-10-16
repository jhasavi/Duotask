import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/task_share.dart';

/// The backend calls behind [TaskShareService], split out so tests can swap
/// in a fake.
abstract class TaskShareApi {
  Future<TaskShare> create(String taskId, {String? recipientName});
  Future<void> revoke(String taskId);
  Future<List<TaskShare>> liveSharesFor(String userId);
  Future<ShareClaimResult> claim(String token);
  Future<SharedTaskPreview> preview(String token);
}

class SupabaseTaskShareApi implements TaskShareApi {
  final SupabaseClient _supabase;
  SupabaseTaskShareApi(this._supabase);

  @override
  Future<TaskShare> create(String taskId, {String? recipientName}) async {
    final row = await _supabase.rpc('create_task_share', params: {
      'p_task_id': taskId,
      'p_recipient_name': recipientName,
    });
    return TaskShare.fromJson(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<void> revoke(String taskId) =>
      _supabase.rpc('revoke_task_share', params: {'p_task_id': taskId});

  @override
  Future<List<TaskShare>> liveSharesFor(String userId) async {
    final rows = await _supabase
        .from('task_shares')
        .select()
        .eq('created_by_id', userId)
        .isFilter('revoked_at', null);
    return (rows as List)
        .map((r) => TaskShare.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Future<ShareClaimResult> claim(String token) async {
    final result =
        await _supabase.rpc('claim_task_share', params: {'p_token': token});
    return ShareClaimResult.fromJson(Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<SharedTaskPreview> preview(String token) async {
    final result =
        await _supabase.rpc('get_shared_task', params: {'p_token': token});
    return SharedTaskPreview.fromJson(Map<String, dynamic>.from(result as Map));
  }
}

/// Sends tasks to people who don't have DuoTask, and turns those people
/// into users.
///
/// The sender creates a link for a task and shares it from their own phone
/// (WhatsApp, text, email). Nothing is sent by the server, so there's no SMS
/// provider, sender registration or per-message cost, and the message comes
/// from someone the recipient knows.
///
/// When the recipient taps "Get DuoTask" on the link page they land on
/// `/?join=<token>`. [captureJoinToken] keeps that token across sign-up
/// (including OAuth and magic-link redirects), and [claimPendingJoin] hands
/// the task to their new account once they're signed in.
class TaskShareService extends ChangeNotifier {
  static const pendingJoinKey = 'pending_share_join_token';

  final TaskShareApi _api;
  final String _appBaseUrl;
  final Map<String, TaskShare> _byTaskId = {};
  RealtimeChannel? _channel;
  final SupabaseClient? _supabase;

  TaskShareService(this._api, {String? appBaseUrl, SupabaseClient? supabase})
      : _appBaseUrl = appBaseUrl ?? AppConfig.publicAppUrl,
        _supabase = supabase;

  factory TaskShareService.supabase(SupabaseClient supabase) =>
      TaskShareService(SupabaseTaskShareApi(supabase), supabase: supabase);

  /// The live link for [taskId], if the user has shared it.
  TaskShare? shareFor(String taskId) => _byTaskId[taskId];

  Uri urlFor(TaskShare share) => TaskShare.buildUrl(_appBaseUrl, share.token);

  /// Loads the user's live links and follows responses in real time.
  Future<void> load(String userId) async {
    try {
      final shares = await _api.liveSharesFor(userId);
      _byTaskId
        ..clear()
        ..addEntries(shares.map((s) => MapEntry(s.taskId, s)));
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Load task shares error: $e');
    }
    _subscribe(userId);
  }

  void _subscribe(String userId) {
    final supabase = _supabase;
    if (supabase == null) return;
    _channel?.unsubscribe();
    _channel = supabase
        .channel('task_shares:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'task_shares',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'created_by_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord.isEmpty) return;
            applyRemoteUpdate(TaskShare.fromJson(payload.newRecord));
          },
        )
        .subscribe();
  }

  @visibleForTesting
  void applyRemoteUpdate(TaskShare share) {
    if (share.isRevoked) {
      if (_byTaskId[share.taskId]?.id == share.id) {
        _byTaskId.remove(share.taskId);
      }
    } else {
      _byTaskId[share.taskId] = share;
    }
    notifyListeners();
  }

  /// Creates the link for [taskId], or returns the existing live one.
  /// Throws a [TaskShareException] with a message fit for the UI.
  Future<TaskShare> share(String taskId, {String? recipientName}) async {
    try {
      final share = await _api.create(taskId, recipientName: recipientName);
      _byTaskId[taskId] = share;
      notifyListeners();
      return share;
    } on PostgrestException catch (e) {
      throw TaskShareException(friendlyError(e.message));
    } on TaskShareException {
      rethrow;
    } catch (e) {
      if (kDebugMode) print('Create task share error: $e');
      throw const TaskShareException(
          "Couldn't create the link. Check your connection and try again.");
    }
  }

  /// Turns off the link for [taskId]; the old URL stops working.
  Future<void> stopSharing(String taskId) async {
    try {
      await _api.revoke(taskId);
      _byTaskId.remove(taskId);
      notifyListeners();
    } on PostgrestException catch (e) {
      throw TaskShareException(friendlyError(e.message));
    } catch (e) {
      if (kDebugMode) print('Revoke task share error: $e');
      throw const TaskShareException(
          "Couldn't turn off the link. Try again.");
    }
  }

  /// Preview for the auth screen's "X sent you a task" banner. Null when the
  /// link is gone or the request fails; the banner just doesn't show.
  Future<SharedTaskPreview?> preview(String token) async {
    try {
      return await _api.preview(token);
    } catch (_) {
      return null;
    }
  }

  // --- Join flow -----------------------------------------------------------

  /// Reads `?join=<token>` from the launch URL (web) and stores it until the
  /// user is signed in. Returns the token, if any.
  static Future<String?> captureJoinToken(Uri launchUri) async {
    final token = launchUri.queryParameters['join'];
    if (!TaskShare.isValidToken(token)) return null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pendingJoinKey, token!);
    return token;
  }

  static Future<String?> pendingJoinToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(pendingJoinKey);
    return TaskShare.isValidToken(token) ? token : null;
  }

  static Future<void> clearPendingJoinToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingJoinKey);
  }

  /// If the user arrived from a share link, gives them the task (and pairs
  /// them with the sender when possible). Returns null when there was
  /// nothing to claim. The stored token is cleared either way, except on a
  /// network failure, so it can be retried on the next launch.
  Future<ShareClaimOutcome?> claimPendingJoin() async {
    final token = await pendingJoinToken();
    if (token == null) return null;
    try {
      final result = await _api.claim(token);
      await clearPendingJoinToken();
      return ShareClaimOutcome.success(result);
    } on PostgrestException catch (e) {
      await clearPendingJoinToken();
      return ShareClaimOutcome.failure(friendlyError(e.message));
    } catch (e) {
      if (kDebugMode) print('Claim task share error: $e');
      return null;
    }
  }

  /// Maps the RPCs' error codes to copy for the user.
  static String friendlyError(String message) {
    switch (message) {
      case 'link_not_found':
        return "That link doesn't exist. Ask for a new one.";
      case 'link_expired':
        return 'That link has expired. Ask for a new one.';
      case 'link_revoked':
        return 'The sender turned that link off.';
      case 'own_link':
        return 'That was your own link, so there was nothing to join.';
      case 'already_claimed':
        return 'Someone else already joined from that link.';
      default:
        return message;
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

class TaskShareException implements Exception {
  final String message;
  const TaskShareException(this.message);
  @override
  String toString() => message;
}

class ShareClaimOutcome {
  final ShareClaimResult? result;
  final String? error;

  const ShareClaimOutcome._(this.result, this.error);
  factory ShareClaimOutcome.success(ShareClaimResult r) =>
      ShareClaimOutcome._(r, null);
  factory ShareClaimOutcome.failure(String message) =>
      ShareClaimOutcome._(null, message);

  bool get isSuccess => result != null;

  /// Snackbar copy after a claim.
  String get message {
    if (error != null) return error!;
    final who = result!.senderName ?? 'the sender';
    return result!.paired
        ? "You're now paired with $who. Your task is on your board."
        : 'The task from $who is now on your board.';
  }
}

import 'package:duotask/models/task_share.dart';
import 'package:duotask/services/task_share_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task_share_test.dart' show shareJson;

class FakeTaskShareApi implements TaskShareApi {
  Object? createError;
  Object? claimError;
  ShareClaimResult claimResult =
      const ShareClaimResult(paired: true, senderName: 'Alex', taskId: 't1');
  final created = <(String, String?)>[];
  final revoked = <String>[];
  final claimed = <String>[];
  List<TaskShare> live = [];

  @override
  Future<TaskShare> create(String taskId, {String? recipientName}) async {
    if (createError != null) throw createError!;
    created.add((taskId, recipientName));
    return TaskShare.fromJson(shareJson({
      'task_id': taskId,
      'recipient_name': recipientName,
    }));
  }

  @override
  Future<void> revoke(String taskId) async => revoked.add(taskId);

  @override
  Future<List<TaskShare>> liveSharesFor(String userId) async => live;

  @override
  Future<ShareClaimResult> claim(String token) async {
    claimed.add(token);
    if (claimError != null) throw claimError!;
    return claimResult;
  }

  @override
  Future<SharedTaskPreview> preview(String token) async =>
      const SharedTaskPreview(title: 'Groceries', senderName: 'Alex');
}

void main() {
  late FakeTaskShareApi api;
  late TaskShareService service;
  const token = 'abcdefghijklmnopqrstuvwx';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = FakeTaskShareApi();
    service = TaskShareService(api, appBaseUrl: 'https://duotask.app');
  });

  test('share caches the link for the task and notifies', () async {
    var notified = 0;
    service.addListener(() => notified++);

    final share = await service.share('t1', recipientName: 'Priya');

    expect(api.created, [('t1', 'Priya')]);
    expect(service.shareFor('t1'), same(share));
    expect(service.urlFor(share).toString(),
        'https://duotask.app/t/abcdefghijklmnopqrstuvwx');
    expect(notified, 1);
  });

  test('share turns a database error into a readable exception', () async {
    api.createError = const PostgrestException(
        message: "Repeating tasks can't be sent by link yet");
    await expectLater(
      service.share('t1'),
      throwsA(isA<TaskShareException>().having((e) => e.message, 'message',
          "Repeating tasks can't be sent by link yet")),
    );
    expect(service.shareFor('t1'), isNull);
  });

  test('share hides unexpected errors behind a generic message', () async {
    api.createError = Exception('socket closed');
    await expectLater(
      service.share('t1'),
      throwsA(isA<TaskShareException>().having(
          (e) => e.message, 'message', contains('Check your connection'))),
    );
  });

  test('stopSharing revokes and forgets the link', () async {
    await service.share('t1');
    await service.stopSharing('t1');
    expect(api.revoked, ['t1']);
    expect(service.shareFor('t1'), isNull);
  });

  test('load replaces the cache with the live links', () async {
    api.live = [TaskShare.fromJson(shareJson({'task_id': 't9'}))];
    await service.load('u1');
    expect(service.shareFor('t9'), isNotNull);
  });

  test('a realtime update replaces the link; a revocation removes it', () {
    service.applyRemoteUpdate(
        TaskShare.fromJson(shareJson({'response': 'done'})));
    expect(service.shareFor('t1')!.response, ShareResponse.done);

    service.applyRemoteUpdate(TaskShare.fromJson(
        shareJson({'revoked_at': '2026-10-17T00:00:00Z'})));
    expect(service.shareFor('t1'), isNull);
  });

  group('join flow', () {
    test('captureJoinToken stores a valid ?join= token only', () async {
      expect(
          await TaskShareService.captureJoinToken(
              Uri.parse('https://duotask.app/?join=$token')),
          token);
      expect(await TaskShareService.pendingJoinToken(), token);

      await TaskShareService.clearPendingJoinToken();
      expect(
          await TaskShareService.captureJoinToken(
              Uri.parse('https://duotask.app/?join=bad')),
          isNull);
      expect(await TaskShareService.pendingJoinToken(), isNull);
    });

    test('claimPendingJoin does nothing without a stored token', () async {
      expect(await service.claimPendingJoin(), isNull);
      expect(api.claimed, isEmpty);
    });

    test('claimPendingJoin claims once and clears the token', () async {
      SharedPreferences.setMockInitialValues(
          {TaskShareService.pendingJoinKey: token});

      final outcome = await service.claimPendingJoin();

      expect(api.claimed, [token]);
      expect(outcome!.isSuccess, isTrue);
      expect(outcome.message, contains("You're now paired with Alex"));
      expect(await TaskShareService.pendingJoinToken(), isNull);
    });

    test('an unpaired claim says the task arrived', () async {
      SharedPreferences.setMockInitialValues(
          {TaskShareService.pendingJoinKey: token});
      api.claimResult = const ShareClaimResult(
          paired: false, senderName: null, taskId: 't1');

      final outcome = await service.claimPendingJoin();
      expect(outcome!.message, 'The task from the sender is now on your board.');
    });

    test('a rejected claim clears the token and explains why', () async {
      SharedPreferences.setMockInitialValues(
          {TaskShareService.pendingJoinKey: token});
      api.claimError = const PostgrestException(message: 'own_link');

      final outcome = await service.claimPendingJoin();
      expect(outcome!.isSuccess, isFalse);
      expect(outcome.message, contains('your own link'));
      expect(await TaskShareService.pendingJoinToken(), isNull);
    });

    test('a network failure keeps the token for the next launch', () async {
      SharedPreferences.setMockInitialValues(
          {TaskShareService.pendingJoinKey: token});
      api.claimError = Exception('offline');

      expect(await service.claimPendingJoin(), isNull);
      expect(await TaskShareService.pendingJoinToken(), token);
    });
  });

  test('friendlyError maps every RPC error code', () {
    for (final code in [
      'link_not_found',
      'link_expired',
      'link_revoked',
      'own_link',
      'already_claimed',
    ]) {
      expect(TaskShareService.friendlyError(code), isNot(code));
    }
    expect(TaskShareService.friendlyError('Other'), 'Other');
  });
}

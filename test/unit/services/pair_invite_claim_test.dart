import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:duotask/models/pair_invite.dart';
import 'package:duotask/models/user.dart';
import 'package:duotask/services/pairing_service.dart';

import '../../test_helpers.mocks.dart';

/// Overrides the two network calls claimPendingInvite builds on, so each
/// outcome can be driven directly.
class _FakePairing extends PairingService {
  bool paired;
  String? statusError;
  bool acceptResult;
  String? acceptError;
  AppUser? fakePartner;
  String? lastAcceptedCode;
  String? _error;

  _FakePairing({
    this.paired = false,
    this.statusError,
    this.acceptResult = true,
    this.acceptError,
    this.fakePartner,
  }) : super(MockSupabaseClient());

  @override
  bool get isPaired => paired;
  @override
  AppUser? get partner => fakePartner;
  @override
  String? get errorMessage => _error;

  @override
  Future<void> checkPairingStatus(String userId) async {
    _error = statusError;
  }

  @override
  Future<bool> acceptPairingCode(String userId, String pairingCode) async {
    lastAcceptedCode = pairingCode;
    _error = acceptResult ? null : acceptError;
    return acceptResult;
  }
}

void main() {
  Future<void> withPendingCode() async {
    SharedPreferences.setMockInitialValues({PairInvite.pendingKey: 'AB12CD34'});
  }

  test('does nothing without a stored invite', () async {
    SharedPreferences.setMockInitialValues({});
    final s = _FakePairing();
    expect(await s.claimPendingInvite('u1'), isNull);
    expect(s.lastAcceptedCode, isNull);
  });

  test('pairs with the stored code and names the partner', () async {
    await withPendingCode();
    final s = _FakePairing(
      fakePartner: AppUser(
        id: 'p',
        email: 'p@x.test',
        displayName: 'Sam',
        createdAt: DateTime(2026),
      ),
    );

    final outcome = await s.claimPendingInvite('u1');

    expect(s.lastAcceptedCode, 'AB12CD34');
    expect(outcome!.paired, isTrue);
    expect(outcome.message, contains('paired with Sam'));
    expect(await PairInvite.pending(), isNull);
  });

  test('an already-paired user is told, and the code is dropped', () async {
    await withPendingCode();
    final s = _FakePairing(paired: true);

    final outcome = await s.claimPendingInvite('u1');

    expect(s.lastAcceptedCode, isNull, reason: 'must not pair twice');
    expect(outcome!.paired, isFalse);
    expect(outcome.message, contains('already paired'));
    expect(await PairInvite.pending(), isNull);
  });

  test('opening your own link says so', () async {
    await withPendingCode();
    final s = _FakePairing(
        acceptResult: false, acceptError: 'Cannot pair with yourself');

    final outcome = await s.claimPendingInvite('u1');

    expect(outcome!.message, contains('your own invite link'));
    expect(await PairInvite.pending(), isNull);
  });

  test('an expired code says so', () async {
    await withPendingCode();
    final s = _FakePairing(
        acceptResult: false, acceptError: 'Invalid or expired pairing code');

    final outcome = await s.claimPendingInvite('u1');

    expect(outcome!.message, contains('expired'));
    expect(await PairInvite.pending(), isNull);
  });

  test('offline: keeps the code for next launch', () async {
    await withPendingCode();
    final offlineCheck = _FakePairing(
        statusError: 'No internet connection. Please check your network.');
    expect(await offlineCheck.claimPendingInvite('u1'), isNull);
    expect(await PairInvite.pending(), 'AB12CD34');

    final offlineAccept = _FakePairing(
        acceptResult: false,
        acceptError: 'Failed to accept pairing. Please try again.');
    expect(await offlineAccept.claimPendingInvite('u1'), isNull);
    expect(await PairInvite.pending(), 'AB12CD34');
  });
}

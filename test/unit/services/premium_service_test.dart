import 'package:flutter_test/flutter_test.dart';

import 'package:duotask/models/premium_status.dart';
import 'package:duotask/services/premium_service.dart';

void main() {
  group('PremiumStatus.fromRpc', () {
    test('parses the first row of a set-returning RPC', () {
      final status = PremiumStatus.fromRpc([
        {
          'is_premium': true,
          'premium_until': '2026-11-14T12:00:00+00:00',
          'via_partner': true,
        },
      ]);
      expect(status.isPremium, true);
      expect(status.viaPartner, true);
      expect(status.premiumUntil, DateTime.utc(2026, 11, 14, 12));
    });

    test('accepts a single map and a null end date', () {
      final status = PremiumStatus.fromRpc({
        'is_premium': true,
        'premium_until': null,
        'via_partner': false,
      });
      expect(status.isPremium, true);
      expect(status.premiumUntil, isNull);
    });

    test('anything unexpected is treated as free', () {
      expect(PremiumStatus.fromRpc(null), PremiumStatus.free);
      expect(PremiumStatus.fromRpc([]), PremiumStatus.free);
      expect(PremiumStatus.fromRpc('oops'), PremiumStatus.free);
      expect(
        PremiumStatus.fromRpc([
          {'is_premium': 'yes'},
        ]).isPremium,
        false,
      );
    });
  });

  group('PremiumService.buildCheckoutUri', () {
    const userId = '3f2b8c1e-9a4d-4e7f-8b2a-1c3d5e7f9a0b';

    test('adds client_reference_id to the payment link', () {
      final uri = PremiumService.buildCheckoutUri(
        'https://buy.stripe.com/test_abc123',
        userId: userId,
      );
      expect(uri.toString(),
          'https://buy.stripe.com/test_abc123?client_reference_id=$userId');
    });

    test('keeps existing query parameters', () {
      final uri = PremiumService.buildCheckoutUri(
        'https://buy.stripe.com/abc?prefilled_promo_code=LAUNCH',
        userId: userId,
      );
      expect(uri!.queryParameters, {
        'prefilled_promo_code': 'LAUNCH',
        'client_reference_id': userId,
      });
    });

    test('returns null when unconfigured or malformed', () {
      expect(PremiumService.buildCheckoutUri('', userId: userId), isNull);
      expect(
        PremiumService.buildCheckoutUri('not a url', userId: userId),
        isNull,
      );
    });
  });

  group('PremiumService state', () {
    const premium = PremiumStatus(isPremium: true);

    test('starts free and not loaded', () {
      final service = PremiumService(() async => premium, paymentLinkUrl: '');
      expect(service.isPremium, false);
      expect(service.hasLoaded, false);
      expect(service.canUpgrade, false);
    });

    test('refresh loads status and notifies', () async {
      final service = PremiumService(() async => premium, paymentLinkUrl: '');
      var notified = 0;
      service.addListener(() => notified++);

      await service.refresh();

      expect(service.isPremium, true);
      expect(service.hasLoaded, true);
      expect(service.isLoading, false);
      expect(notified, greaterThanOrEqualTo(2)); // loading on, then off
    });

    test('a failed refresh keeps the last known status', () async {
      var fail = false;
      final service = PremiumService(
        () async => fail ? throw Exception('offline') : premium,
        paymentLinkUrl: '',
      );
      await service.refresh();
      fail = true;
      await service.refresh();

      expect(service.isPremium, true);
      expect(service.isLoading, false);
    });

    test('reset returns to free', () async {
      final service = PremiumService(() async => premium, paymentLinkUrl: '');
      await service.refresh();
      service.reset();
      expect(service.isPremium, false);
      expect(service.hasLoaded, false);
    });

    test('checkoutUri and portal follow configuration', () {
      final service = PremiumService(
        () async => premium,
        paymentLinkUrl: 'https://buy.stripe.com/x',
        customerPortalUrl: 'https://billing.stripe.com/p/login/y',
      );
      expect(service.canUpgrade, true);
      expect(service.canManage, true);
      expect(
        service.checkoutUri('u1')!.queryParameters['client_reference_id'],
        'u1',
      );
      expect(service.customerPortalUri.toString(),
          'https://billing.stripe.com/p/login/y');
    });
  });
}

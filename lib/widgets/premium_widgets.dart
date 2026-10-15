import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/premium_service.dart';

/// Opens Stripe Checkout for the signed-in user. On the web this replaces
/// the current tab, so Stripe's "after payment" redirect lands back in the
/// app, which re-reads premium status on load.
Future<void> openPremiumCheckout(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final userId = context.read<AuthService>().currentUser?.id;
  final uri = userId == null
      ? null
      : context.read<PremiumService>().checkoutUri(userId);

  if (uri == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Upgrades are not available yet.')),
    );
    return;
  }

  final opened = await launchUrl(uri, webOnlyWindowName: '_self');
  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not open the checkout page.')),
    );
  }
}

Future<void> openPremiumPortal(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = context.read<PremiumService>().customerPortalUri;
  if (uri == null || !await launchUrl(uri, webOnlyWindowName: '_self')) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not open subscription settings.')),
    );
  }
}

/// One-line description of the current plan, for Settings.
String premiumStatusLabel(PremiumService premium) {
  final status = premium.status;
  if (!status.isPremium) return 'Free plan';
  final until = status.premiumUntil;
  final renews = until == null
      ? ''
      : ' · paid through ${DateFormat.yMMMd().format(until.toLocal())}';
  return status.viaPartner
      ? 'Premium, shared by your partner$renews'
      : 'Premium$renews';
}

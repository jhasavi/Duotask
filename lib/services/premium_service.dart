import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/premium_status.dart';

/// Tracks whether the signed-in user (or their partner) has DuoTask Premium.
///
/// Premium is bought on the web through a Stripe Payment Link; the
/// `stripe-webhook` Edge Function records the result in `users.is_premium`,
/// and this service reads it back through the `get_premium_status` RPC.
/// Nothing here can grant premium — the database rejects client writes to
/// those columns.
class PremiumService extends ChangeNotifier {
  final Future<PremiumStatus> Function() _loadStatus;
  final String _paymentLinkUrl;
  final String _customerPortalUrl;

  PremiumStatus _status = PremiumStatus.free;
  bool _isLoading = false;
  bool _hasLoaded = false;

  PremiumService(
    this._loadStatus, {
    String? paymentLinkUrl,
    String? customerPortalUrl,
  })  : _paymentLinkUrl = paymentLinkUrl ?? AppConfig.stripePaymentLinkUrl,
        _customerPortalUrl =
            customerPortalUrl ?? AppConfig.stripeCustomerPortalUrl;

  factory PremiumService.supabase(SupabaseClient supabase) {
    return PremiumService(
      () async => PremiumStatus.fromRpc(
        await supabase.rpc('get_premium_status'),
      ),
    );
  }

  PremiumStatus get status => _status;
  bool get isPremium => _status.isPremium;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;

  /// Whether an upgrade button can do anything in this build.
  bool get canUpgrade => _paymentLinkUrl.isNotEmpty;
  bool get canManage => _customerPortalUrl.isNotEmpty;

  /// Re-reads premium state. Failures leave the last known state in place
  /// rather than flipping a paying user to free on a network blip.
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    try {
      _status = await _loadStatus();
      _hasLoaded = true;
    } catch (e) {
      if (kDebugMode) print('Premium status error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Call on sign-out so the next account doesn't inherit this one's state.
  void reset() {
    _status = PremiumStatus.free;
    _hasLoaded = false;
    notifyListeners();
  }

  /// The checkout URL for [userId], or null if no Payment Link is
  /// configured.
  Uri? checkoutUri(String userId) =>
      buildCheckoutUri(_paymentLinkUrl, userId: userId);

  Uri? get customerPortalUri =>
      _customerPortalUrl.isEmpty ? null : Uri.tryParse(_customerPortalUrl);

  /// Appends `client_reference_id` to a Stripe Payment Link so the webhook
  /// can tell which DuoTask account paid. Existing query parameters (e.g. a
  /// `prefilled_promo_code`) are kept.
  static Uri? buildCheckoutUri(String paymentLinkUrl,
      {required String userId}) {
    if (paymentLinkUrl.isEmpty) return null;
    final base = Uri.tryParse(paymentLinkUrl);
    if (base == null || !base.hasScheme) return null;
    return base.replace(
      queryParameters: {
        ...base.queryParameters,
        'client_reference_id': userId,
      },
    );
  }
}

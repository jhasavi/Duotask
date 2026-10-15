/// The caller's effective premium state, as reported by the
/// `get_premium_status` RPC. A pair shares one subscription, so
/// [viaPartner] is true when the partner is the one paying.
class PremiumStatus {
  final bool isPremium;
  final DateTime? premiumUntil;
  final bool viaPartner;

  const PremiumStatus({
    required this.isPremium,
    this.premiumUntil,
    this.viaPartner = false,
  });

  static const free = PremiumStatus(isPremium: false);

  /// Parses the RPC result. PostgREST returns a set-returning function as a
  /// list of rows; a single map is accepted too.
  factory PremiumStatus.fromRpc(dynamic response) {
    final row = switch (response) {
      List<dynamic> rows when rows.isNotEmpty => rows.first,
      Map<String, dynamic> map => map,
      _ => null,
    };
    if (row is! Map) return free;

    final until = row['premium_until'];
    return PremiumStatus(
      isPremium: row['is_premium'] == true,
      premiumUntil: until is String ? DateTime.tryParse(until) : null,
      viaPartner: row['via_partner'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PremiumStatus &&
      other.isPremium == isPremium &&
      other.premiumUntil == premiumUntil &&
      other.viaPartner == viaPartner;

  @override
  int get hashCode => Object.hash(isPremium, premiumUntil, viaPartner);
}

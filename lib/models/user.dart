class DuoUser {
  final String id;
  final String name;
  final String email;
  final String pairCode;
  final String? pairedWith;
  final DateTime? lastActive;
  final String? fcmToken;
  final String subscriptionTier;

  DuoUser({
    required this.id,
    required this.name,
    required this.email,
    required this.pairCode,
    this.pairedWith,
    this.lastActive,
    this.fcmToken,
    this.subscriptionTier = 'free',
  });

  factory DuoUser.fromMap(Map<String, dynamic> map) {
    return DuoUser(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      pairCode: map['pair_code'] as String,
      pairedWith: map['paired_with'] as String?,
      lastActive: map['last_active'] != null
          ? DateTime.parse(map['last_active'])
          : null,
      fcmToken: map['fcm_token'] as String?,
      subscriptionTier: map['subscription_tier'] ?? 'free',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'pair_code': pairCode,
      'paired_with': pairedWith,
      'last_active': lastActive?.toIso8601String(),
      'fcm_token': fcmToken,
      'subscription_tier': subscriptionTier,
    };
  }
}

class AppUser {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String? pairingCode;
  final String? pairedWithId;
  final String? pairedWithName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.pairingCode,
    this.pairedWithId,
    this.pairedWithName,
    required this.createdAt,
    this.updatedAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      pairingCode: json['pairing_code'] as String?,
      pairedWithId: json['paired_with_id'] as String?,
      pairedWithName: json['paired_with_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'pairing_code': pairingCode,
      'paired_with_id': pairedWithId,
      'paired_with_name': pairedWithName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    String? pairingCode,
    String? pairedWithId,
    String? pairedWithName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      pairingCode: pairingCode ?? this.pairingCode,
      pairedWithId: pairedWithId ?? this.pairedWithId,
      pairedWithName: pairedWithName ?? this.pairedWithName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPaired => pairedWithId != null && pairedWithId!.isNotEmpty;

  @override
  String toString() {
    return 'AppUser(id: $id, email: $email, displayName: $displayName, isPaired: $isPaired)';
  }
}

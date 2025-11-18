enum PairingStatus {
  pending,
  active,
  rejected,
  cancelled;

  String get displayName {
    switch (this) {
      case PairingStatus.pending:
        return 'Pending';
      case PairingStatus.active:
        return 'Active';
      case PairingStatus.rejected:
        return 'Rejected';
      case PairingStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class Pairing {
  final String id;
  final String requesterId;
  final String? recipientId;
  final String pairingCode;
  final PairingStatus status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? updatedAt;

  Pairing({
    required this.id,
    required this.requesterId,
    this.recipientId,
    required this.pairingCode,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.updatedAt,
  });

  factory Pairing.fromJson(Map<String, dynamic> json) {
    return Pairing(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      recipientId: json['recipient_id'] as String?,
      pairingCode: json['pairing_code'] as String,
      status: PairingStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PairingStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requester_id': requesterId,
      'recipient_id': recipientId,
      'pairing_code': pairingCode,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Pairing copyWith({
    String? id,
    String? requesterId,
    String? recipientId,
    String? pairingCode,
    PairingStatus? status,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? updatedAt,
  }) {
    return Pairing(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      recipientId: recipientId ?? this.recipientId,
      pairingCode: pairingCode ?? this.pairingCode,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isActive => status == PairingStatus.active;
  bool get isPending => status == PairingStatus.pending;

  @override
  String toString() {
    return 'Pairing(id: $id, code: $pairingCode, status: ${status.displayName})';
  }
}

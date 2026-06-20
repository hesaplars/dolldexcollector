enum ProStatus {
  free,
  active,
  gracePeriod,
  expired,
}

class ProEntitlement {
  const ProEntitlement({
    required this.userId,
    required this.status,
    required this.isServerVerified,
    this.expiresAt,
    this.productId = '',
  });

  final String userId;
  final ProStatus status;
  final bool isServerVerified;
  final DateTime? expiresAt;
  final String productId;

  bool get isPro {
    return isServerVerified &&
        (status == ProStatus.active || status == ProStatus.gracePeriod);
  }

  Map<String, Object?> toMap() {
    return {
      'userId': userId,
      'status': status.name,
      'isServerVerified': isServerVerified,
      'expiresAt': expiresAt?.toIso8601String(),
      'productId': productId,
    };
  }

  factory ProEntitlement.free(String userId) {
    return ProEntitlement(
      userId: userId,
      status: ProStatus.free,
      isServerVerified: true,
    );
  }
}

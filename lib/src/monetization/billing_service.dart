class BillingService {
  const BillingService();

  static const proMonthlyProductId = 'dolldex_pro_monthly';
  static const proYearlyProductId = 'dolldex_pro_yearly';

  Future<bool> get isAvailable async => false;

  Future<List<String>> loadProProducts() async {
    return const [
      proMonthlyProductId,
      proYearlyProductId,
    ];
  }

  Future<void> buySubscription(String productId) async {
    throw UnimplementedError(
      'Google Play Billing will be enabled after Play Console setup.',
    );
  }
}

class ServerPurchaseVerifier {
  const ServerPurchaseVerifier();

  Future<void> verifyPurchaseWithServer({
    required String productId,
    required String purchaseToken,
  }) async {
    throw UnimplementedError(
      'Server purchase verification will be enabled after Google Play API setup.',
    );
  }
}

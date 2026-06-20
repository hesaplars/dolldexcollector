class AdService {
  const AdService();

  Future<void> initialize() async {}

  bool shouldShowAds({
    required bool isPro,
  }) {
    return !isPro;
  }
}

// ignore: avoid_web_libraries_in_flutter
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, ValueNotifier;
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Merkezi reklam servisi — platform-aware singleton.
/// Web'de stub olarak çalışır (AdSense ayrı olarak web_ad_bridge.dart ile yönetilir).
/// Android'de AdMob SDK kullanır.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ── Global Pro Status ───────────────────────────────────────────────────
  static final ValueNotifier<bool> isProNotifier = ValueNotifier<bool>(false);

  // ── Test Ad Unit ID'leri ────────────────────────────────────────────────
  // Production'da AdMob konsolundan alınan gerçek ID'lerle değiştirilecek.
  static const _androidBannerTestId =
      'ca-app-pub-3940256099942544/6300978111';
  static const _androidInterstitialTestId =
      'ca-app-pub-3940256099942544/1033173712';
  static const _androidRewardedTestId =
      'ca-app-pub-3940256099942544/5224354917';

  // ── State ───────────────────────────────────────────────────────────────
  bool _initialized = false;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  DateTime? _lastInterstitialShown;

  // Interstitial gösterim için minimum bekleme süresi
  static const _interstitialCooldown = Duration(minutes: 3);

  // ── Init ────────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    _preloadInterstitial();
    _preloadRewarded();
  }

  // ── Banner ──────────────────────────────────────────────────────────────

  /// Banner reklam oluşturur ve yüklemeye başlar.
  /// Widget içinde [AdBannerWidget] tarafından yönetilir.
  BannerAd createBannerAd({AdSize size = AdSize.banner}) {
    return BannerAd(
      adUnitId: _androidBannerTestId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
  }

  // ── Interstitial ────────────────────────────────────────────────────────

  void _preloadInterstitial() {
    if (kIsWeb || !Platform.isAndroid || !_initialized) return;
    InterstitialAd.load(
      adUnitId: _androidInterstitialTestId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          ad.setImmersiveMode(true);
        },
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  /// Interstitial göster. Pro kullanıcılara gösterilmez.
  /// Cooldown süresi geçmemişse gösterilmez.
  Future<void> showInterstitial({required bool isPro}) async {
    if (isPro) return;
    if (kIsWeb || !Platform.isAndroid || !_initialized) return;
    if (_interstitialAd == null) return;

    final now = DateTime.now();
    if (_lastInterstitialShown != null &&
        now.difference(_lastInterstitialShown!) < _interstitialCooldown) {
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _preloadInterstitial(); // bir sonraki için hazırla
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitialAd = null;
        _preloadInterstitial();
      },
    );

    _lastInterstitialShown = now;
    await _interstitialAd!.show();
  }

  // ── Rewarded ────────────────────────────────────────────────────────────

  void _preloadRewarded() {
    if (kIsWeb || !Platform.isAndroid || !_initialized) return;
    RewardedAd.load(
      adUnitId: _androidRewardedTestId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (_) => _rewardedAd = null,
      ),
    );
  }

  bool get isRewardedReady =>
      !kIsWeb && Platform.isAndroid && _rewardedAd != null;

  /// Rewarded video göster. Pro + normal kullanıcı için çalışır.
  /// [onEarned] → kullanıcı reklamı tamamlayınca çağrılır.
  Future<void> showRewarded({required void Function() onEarned}) async {
    if (kIsWeb || !Platform.isAndroid || _rewardedAd == null) {
      // Web veya hazır değilse direkt ödülü ver (geliştirme/test modu)
      onEarned();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _preloadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedAd = null;
        _preloadRewarded();
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (_, __) => onEarned(),
    );
  }
}

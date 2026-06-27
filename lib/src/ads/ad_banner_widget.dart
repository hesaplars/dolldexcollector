import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_service.dart';

/// Platform-aware banner reklam widget'ı.
/// - Android → AdMob BannerAd
/// - Web → AdSense overlay (web_ad_bridge.dart, sonraki aşama)
/// - isPro = true → SizedBox.shrink() (görünmez)
///
/// [isPro] null bırakılırsa Firestore'dan otomatik çeker.
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({
    super.key,
    this.isPro,
    this.adSize = AdSize.banner,
  });

  /// null → Firebase'den otomatik al
  final bool? isPro;
  final AdSize adSize;

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    AdService.isProNotifier.addListener(_onProStatusChanged);
    _checkAndLoadAd();
  }

  void _onProStatusChanged() {
    if (AdService.isProNotifier.value) {
      _bannerAd?.dispose();
      _bannerAd = null;
      if (mounted) setState(() => _isLoaded = false);
    } else {
      _checkAndLoadAd();
    }
  }

  void _checkAndLoadAd() {
    final pro = widget.isPro ?? AdService.isProNotifier.value;
    if (!pro && _bannerAd == null) {
      _loadBanner();
    }
  }

  void _loadBanner() {
    if (kIsWeb || !Platform.isAndroid) return;
    _bannerAd = AdService.instance.createBannerAd(size: widget.adSize)
      ..load().then((_) {
        if (mounted) setState(() => _isLoaded = true);
      });
  }

  @override
  void dispose() {
    AdService.isProNotifier.removeListener(_onProStatusChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AdService.isProNotifier,
      builder: (context, globalIsPro, _) {
        final isPro = widget.isPro ?? globalIsPro;
        if (isPro) return const SizedBox.shrink();

        // Web → AdSense placeholder (publisher ID alındığında aktif edilir)
        if (kIsWeb) return _WebAdSenseBanner(adSize: widget.adSize);

        // Android → AdMob banner
        if (!_isLoaded || _bannerAd == null) {
          return SizedBox(
            height: widget.adSize.height.toDouble(),
            width: widget.adSize.width.toDouble(),
          );
        }

        return SizedBox(
          height: _bannerAd!.size.height.toDouble(),
          width: _bannerAd!.size.width.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        );
      },
    );
  }
}


/// Web için AdSense banner placeholder (Simüle edilmiş test reklamı).
class _WebAdSenseBanner extends StatelessWidget {
  const _WebAdSenseBanner({required this.adSize});
  final AdSize adSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final width = adSize.width.toDouble();
    final height = adSize.height.toDouble();

    return Center(
      child: Container(
        width: width > 0 ? width : 320,
        height: height > 0 ? height : 50,
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F1235) : const Color(0xFFF7F4FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Sol üst "Google Ads" etiketi
              Positioned(
                top: 4,
                left: 6,
                child: Text(
                  'Google AdSense (Test)',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary.withValues(alpha: 0.6),
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              // Sağ üst bilgi ikonu
              Positioned(
                top: 4,
                right: 6,
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              // Orta: Reklam içeriği simülasyonu
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.campaign_outlined,
                          color: theme.colorScheme.primary,
                          size: height > 60 ? 24 : 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sponsorlu Bağlantı',
                          style: TextStyle(
                            fontSize: height > 60 ? 12.5 : 11,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Outfit',
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    if (height > 60) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Bu bir simüle edilmiş web reklam alanıdır.',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontFamily: 'Outfit',
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Liste içine yerleştirilen reklam slotu (GridView / ListView için).
/// isPro veya platform uyumlu değilse SizedBox.shrink() döner.
class AdGridSlotWidget extends StatelessWidget {
  const AdGridSlotWidget({super.key, required this.isPro});
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    if (isPro) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: AdBannerWidget(
        isPro: isPro,
        adSize: AdSize.mediumRectangle,
      ),
    );
  }
}

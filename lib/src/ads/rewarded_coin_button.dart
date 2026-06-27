import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'ad_service.dart';

/// "Reklam İzle → +10 Jeton Kazan" butonu.
/// Pro kullanıcı dahil herkese gösterilir.
/// Jeton kazanımı [onCoinsEarned] callback'i ile bildirilir.
class RewardedCoinButton extends StatefulWidget {
  const RewardedCoinButton({
    super.key,
    required this.onCoinsEarned,
    this.dailyWatchCount = 0,
    this.maxDailyWatch = 5,
  });

  final VoidCallback onCoinsEarned;
  final int dailyWatchCount;
  final int maxDailyWatch;

  @override
  State<RewardedCoinButton> createState() => _RewardedCoinButtonState();
}

class _RewardedCoinButtonState extends State<RewardedCoinButton> {
  bool _isLoading = false;

  bool get _canWatch =>
      widget.dailyWatchCount < widget.maxDailyWatch &&
      (kIsWeb || AdService.instance.isRewardedReady);

  Future<void> _handleWatch() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await AdService.instance.showRewarded(
        onEarned: widget.onCoinsEarned,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final remaining = widget.maxDailyWatch - widget.dailyWatchCount;
    final exhausted = widget.dailyWatchCount >= widget.maxDailyWatch;

    return AnimatedOpacity(
      opacity: exhausted ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: InkWell(
        onTap: (_canWatch && !_isLoading) ? _handleWatch : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: exhausted
                ? null
                : LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.15),
                      const Color(0xFFFFB300).withValues(alpha: 0.10),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            color: exhausted
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05))
                : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: exhausted
                  ? theme.dividerColor
                  : accent.withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                )
              else
                Icon(
                  exhausted
                      ? Icons.check_circle_outline_rounded
                      : Icons.play_circle_outline_rounded,
                  size: 18,
                  color: exhausted ? theme.colorScheme.onSurface.withValues(alpha: 0.4) : accent,
                ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    exhausted
                        ? (Localizations.localeOf(context).languageCode == 'tr'
                            ? 'Günlük limit doldu'
                            : 'Daily limit reached')
                        : (Localizations.localeOf(context).languageCode == 'tr'
                            ? '🎬 Reklam İzle'
                            : '🎬 Watch Ad'),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Outfit',
                      color: exhausted
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                          : accent,
                    ),
                  ),
                  Text(
                    exhausted
                        ? (Localizations.localeOf(context).languageCode == 'tr'
                            ? 'Yarın tekrar dene'
                            : 'Try again tomorrow')
                        : (Localizations.localeOf(context).languageCode == 'tr'
                            ? '+10 Jeton • $remaining kez kaldı'
                            : '+10 Coins • $remaining left'),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontFamily: 'Outfit',
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

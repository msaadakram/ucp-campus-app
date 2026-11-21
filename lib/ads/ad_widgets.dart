import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../theme/palette.dart';
import '../widgets/common.dart';
import 'admob_service.dart';

export 'admob_service.dart';

/// A screen-width adaptive banner.
///
/// Nothing is rendered until an ad actually arrives: no fill must never
/// leave an empty grey box on the screen.
class AdBanner extends StatefulWidget {
  const AdBanner({
    super.key,
    this.adUnitId = AdMobIds.banner,
    this.margin = const EdgeInsets.only(top: 14, bottom: 4),
  });

  final String adUnitId;
  final EdgeInsetsGeometry margin;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  AdSize? _loadedSize;
  bool _requested = false;

  bool _detached = false;
  VoidCallback? _readySub;
  Timer? _retryTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    final ads = AdMobService.instance;
    if (ads.ready) {
      _requested = true;
      _load();
    } else {
      // The SDK initializes after the policy gate — banners that show up
      // in the meanwhile wait for it instead of silently never loading.
      _readySub = () {
        if (_detached || _requested || !ads.readyNotifier.value) return;
        _requested = true;
        _load();
      };
      ads.readyNotifier.addListener(_readySub!);
    }
  }

  static const Duration _retryDelay = Duration(seconds: 8);

  Future<void> _load() async {
    final ads = AdMobService.instance;
    if (_ad != null || !ads.ready) return;
    try {
      final width = MediaQuery.of(context).size.width.truncate();
      final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
      if (!mounted) return;
      late final BannerAd ad;
      ad = BannerAd(
        adUnitId: widget.adUnitId,
        size: size ?? AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (!mounted) return;
            setState(() {
              _ad = ad;
              _loadedSize = ad.size;
            });
          },
          onAdFailedToLoad: (failedAd, error) {
            debugPrint('AdMob: banner no fill (${error.code})');
            failedAd.dispose();
            _retryAfter(_load);
          },
        ),
      );
      await ad.load();
      if (!mounted) {
        ad.dispose();
        return;
      }
      _ad = ad;
    } catch (e) {
      debugPrint('AdMob: banner failed ($e)');
    }
  }

  /// A no-fill banner retries briefly so a broken/offline window self
  /// heals instead of staying dark forever.
  void _retryAfter(Future<void> Function() fn) {
    _retryTimer = Timer(_retryDelay, () {
      _retryTimer = null;
      fn();
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _detached = true;
    if (_readySub != null) {
      AdMobService.instance.readyNotifier.removeListener(_readySub!);
    }
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final ad = _ad;
    final size = _loadedSize;
    if (ad == null || size == null) return const SizedBox.shrink();
    return Padding(
      padding: widget.margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ads are labelled as ads — required disclosure.
          Text(
            'ADVERTISEMENT',
            style: body(
              c,
              size: 9,
              weight: FontWeight.w700,
              color: c.tealInk.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            height: size.height.toDouble(),
            decoration: BoxDecoration(
              color: c.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.dustSoft.withValues(alpha: 0.5)),
            ),
            clipBehavior: Clip.antiAlias,
            child: AdWidget(ad: ad),
          ),
        ],
      ),
    );
  }
}

/// A native advanced ad rendered with the SDK's own template.
///
/// The template already ships the AdChoices badge and the "Ad" label.
class AdNativeCard extends StatefulWidget {
  const AdNativeCard({
    super.key,
    this.adUnitId = AdMobIds.nativeAdvanced,
    this.height = 330,
    this.margin = const EdgeInsets.only(top: 14, bottom: 6),
  });

  final String adUnitId;
  final double height;
  final EdgeInsetsGeometry margin;

  @override
  State<AdNativeCard> createState() => _AdNativeCardState();
}

class _AdNativeCardState extends State<AdNativeCard> {
  NativeAd? _ad;
  bool _requested = false;
  bool _detached = false;
  VoidCallback? _readySub;
  Timer? _retryTimer;

  static const Duration _retryDelay = Duration(seconds: 8);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    final ads = AdMobService.instance;
    if (ads.ready) {
      _requested = true;
      _load();
    } else {
      // Cards that mount before the SDK is ready wait for it, then load —
      // no "I'm open now, and the ad will show up later" gap.
      _readySub = () {
        if (_detached || _requested || !ads.readyNotifier.value) return;
        _requested = true;
        _load();
      };
      ads.readyNotifier.addListener(_readySub!);
    }
  }

  Future<void> _load() async {
    final ads = AdMobService.instance;
    if (_ad != null || !ads.ready) return;
    try {
      late final NativeAd ad;
      ad = NativeAd(
        adUnitId: widget.adUnitId,
        request: const AdRequest(),
        nativeAdOptions: NativeAdOptions(
          shouldRequestMultipleImages: true,
          adChoicesPlacement: AdChoicesPlacement.topRightCorner,
        ),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: TemplateType.medium,
          mainBackgroundColor: Colors.white,
          cornerRadius: 16,
          primaryTextStyle: NativeTemplateTextStyle(
            textColor: const Color(0xFF101820),
            backgroundColor: Colors.white,
            size: 15,
            style: NativeTemplateFontStyle.bold,
          ),
          secondaryTextStyle: NativeTemplateTextStyle(
            textColor: const Color(0xFF5A6672),
            backgroundColor: Colors.white,
            size: 13,
          ),
          tertiaryTextStyle: NativeTemplateTextStyle(
            textColor: const Color(0xFF8C98A4),
            backgroundColor: Colors.white,
            size: 12,
          ),
          callToActionTextStyle: NativeTemplateTextStyle(
            textColor: Colors.white,
            backgroundColor: const Color(0xFF0E7C86),
            size: 14,
            style: NativeTemplateFontStyle.bold,
          ),
        ),
        listener: NativeAdListener(
          onAdLoaded: (_) {
            if (!mounted) return;
            setState(() => _ad = ad);
          },
          onAdFailedToLoad: (failedAd, error) {
            debugPrint('AdMob: native no fill (${error.code})');
            failedAd.dispose();
            _retryTimer = Timer(_retryDelay, () {
              _retryTimer = null;
              _load();
            });
          },
        ),
      );
      await ad.load();
      if (!mounted) {
        ad.dispose();
        return;
      }
      _ad = ad;
    } catch (e) {
      debugPrint('AdMob: native failed ($e)');
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _detached = true;
    if (_readySub != null) {
      AdMobService.instance.readyNotifier.removeListener(_readySub!);
    }
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return Padding(
      padding: widget.margin,
      child: Container(
        width: double.infinity,
        height: widget.height,
        decoration: BoxDecoration(
          color: c.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.dustSoft.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: AdWidget(ad: ad),
      ),
    );
  }
}

/// One standard section of ads at the end of a page: a native advanced
/// card plus an adaptive banner. Both render nothing until a fill arrives,
/// so a missing fill never leaves an empty grey box.
class AdSection extends StatelessWidget {
  const AdSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AdsConfig.otherPagesAds) return const SizedBox.shrink();
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [AdNativeCard(), AdBanner()],
    );
  }
}

/// Bottom sheet offering a rewarded ad.
///
/// Mandatory on the leaderboard (see [AdsConfig.leaderboardMandatoryAd]):
/// the sheet cannot be dismissed — the student MUST finish with an
/// explicit choice — but "No thanks, continue" always works, so the app
/// itself is never gated. Google allows this pattern; forcing "Watch
/// ad" or blocking the screen behind it is not.
Future<bool> showRewardedOffer(
  BuildContext context, {
  required String title,
  required String rewardText,
  required Future<void> Function() onReward,
}) async {
  final ads = AdMobService.instance;
  if (!ads.ready) return false;
  ads.preloadRewarded();
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false, // must end on an explicit choice
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _RewardedOfferSheet(
      title: title,
      rewardText: rewardText,
      onReward: onReward,
    ),
  );
  return result == true;
}

class _RewardedOfferSheet extends StatefulWidget {
  const _RewardedOfferSheet({
    required this.title,
    required this.rewardText,
    required this.onReward,
  });

  final String title;
  final String rewardText;
  final Future<void> Function() onReward;

  @override
  State<_RewardedOfferSheet> createState() => _RewardedOfferSheetState();
}

class _RewardedOfferSheetState extends State<_RewardedOfferSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _watch() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final earned = await AdMobService.instance.showRewarded(
      onReward: () {},
    );
    if (!mounted) return;
    if (!earned) {
      setState(() {
        _busy = false;
        _error = 'No ad available right now — try again in a moment.';
      });
      return;
    }
    await widget.onReward();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        18 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: c.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: c.dustSoft,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.ondemand_video_outlined, color: c.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: display(c, size: 17, color: c.tealInk),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.rewardText,
            style: body(c, size: 13, color: c.tealInk.withValues(alpha: 0.75)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: body(c, size: 12, color: c.clay),
            ),
          ],
          const SizedBox(height: 16),
          // Primary: watch the ad. Secondary: skip (always available).
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _busy ? null : _watch,
              style: FilledButton.styleFrom(
                backgroundColor: c.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Watch ad',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 46,
            child: TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: c.tealInk.withValues(alpha: 0.7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'No thanks, continue',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

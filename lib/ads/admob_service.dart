import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob identifiers for the "UCP University" app.
///
/// These are PUBLIC identifiers from the AdMob console — the SDK needs them
/// inside the binary, they are NOT secrets (unlike the backend service key
/// or the signing keystore).
class AdMobIds {
  const AdMobIds._();

  /// AdMob APPLICATION_ID — goes into AndroidManifest.xml as
  /// `com.google.android.gms.ads.APPLICATION_ID`.
  static const String appId = 'ca-app-pub-6696399034620004~8106102480';

  /// App open ad unit.
  static const String appOpen = 'ca-app-pub-6696399034620004/3229160845';

  /// Banner ad unit.
  static const String banner = 'ca-app-pub-6696399034620004/7614916389';

  /// Interstitial ad unit.
  static const String interstitial = 'ca-app-pub-6696399034620004/8206155358';

  /// Native advanced ad unit.
  static const String nativeAdvanced =
      'ca-app-pub-6696399034620004/8289915832';

  /// Rewarded ad unit.
  static const String rewarded = 'ca-app-pub-6696399034620004/9794569198';

  /// Rewarded interstitial ad unit.
  static const String rewardedInterstitial =
      'ca-app-pub-6696399034620004/6584905743';
}

/// Feature switches for the ad placements. Flip these to change where ads
/// appear without touching the screens.
class AdsConfig {
  const AdsConfig._();

  /// The leaderboard is the ad-heavy screen: rewarded offer on every view,
  /// a banner under the ranks and a native card above it.
  static const bool leaderboardAds = true;

  /// The offer sheet shown on every leaderboard view is mandatory
  /// (non-dismissible, requires an explicit choice) — every other page
  /// still works normally, so this stays Google-compliant.
  static const bool leaderboardMandatoryAd = true;

  /// Native advanced card on Home.
  static const bool nativeOnHome = true;

  /// Banner on Home and on other pages (Attendance, Results, Fee, GPA,
  /// Teachers, Community).
  static const bool bannerOnHome = true;

  /// One standard section of ads at the end of other pages: native card +
  /// adaptive banner.
  static const bool otherPagesAds = true;

  /// Rewarded offer sheet on every leaderboard view.
  static const bool rewardedOnLeaderboard = true;

  /// Interstitial on section transitions (Home -> a section).
  static const bool interstitialOnSectionChange = true;
}

/// One tiny wrapper around the Google Mobile Ads SDK.
///
/// Design rules that keep the app (and the AdMob account) safe:
///  * every SDK call is wrapped — a broken/failed ad NEVER breaks a screen;
///  * the SDK is only initialized AFTER the student accepted the app policy
///    (the app promises "nothing leaves the device until you agree");
///  * rewarded ads are always user-initiated and never block the app
///    (Google's rewarded-ad policy: skipping must never impede normal use);
///  * full-screen ads have cooldowns so the app never nags.
class AdMobService {
  AdMobService._();

  static final AdMobService instance = AdMobService._();

  /// True once the SDK initialized successfully. False in widget tests (no
  /// platform channels) and on any initialization failure.
  bool ready = false;

  /// Notifies ready listeners whenever initialization succeeds or fails.
  final ValueNotifier<bool> readyNotifier = ValueNotifier(false);

  final _readyWaiters = <Completer<void>>[];

  /// Resolves once the SDK is ready (or immediately when it is).
  ///
  /// [timeout] bounds how long callers wait: after that we give up and
  /// return the best known state, so a hanging SDK can never wedge the UI.
  Future<bool> whenReady({Duration timeout = const Duration(seconds: 15)}) async {
    if (ready) return true;
    final w = Completer<void>();
    _readyWaiters.add(w);
    try {
      await w.future.timeout(timeout);
      return true;
    } catch (_) {
      return ready;
    }
  }

  void _notifyReady(bool ok) {
    if (readyNotifier.value == ok && _readyWaiters.isEmpty) return;
    readyNotifier.value = ok;
    for (final w in _readyWaiters) {
      if (!w.isCompleted) w.complete();
    }
    _readyWaiters.clear();
  }

  bool _initializing = false;
  AppOpenAd? _appOpen;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _rewardedLoading = false;

  /// A full-screen ad is on screen right now (no second one may start).
  bool _fullScreenBusy = false;

  DateTime? _lastInterstitialAt;
  DateTime? _lastFullScreenAt;
  DateTime? _pausedAt;

  /// Section transitions since launch (the first one is ad-free so a
  /// fresh student never gets an ad by accident).
  int _sectionChanges = 0;

  /// Minimum gap between two interstitials.
  static const Duration interstitialCooldown = Duration(minutes: 2);

  /// Minimum gap between ANY two full-screen ads (app open / interstitial /
  /// rewarded) so they never stack up.
  static const Duration fullScreenCooldown = Duration(seconds: 45);

  /// App open ads are only offered after the app was away for a while.
  static const Duration appOpenResumeThreshold = Duration(seconds: 30);

  /// Initializes the SDK (consent -> initialize -> preload).
  ///
  /// Safe to call more than once; only the first call does the work.
  Future<void> initialize() async {
    if (ready || _initializing) return;
    _initializing = true;
    try {
      await _applyRequestConfiguration();
      await _collectConsent();
      await MobileAds.instance.initialize();
      ready = true;
      _notifyReady(true);
      _loadAppOpen();
      _loadRewarded();
      _loadInterstitial();
    } catch (e) {
      debugPrint('AdMob: initialization failed ($e) — ads stay off.');
      ready = false;
      _notifyReady(false);
    } finally {
      _initializing = false;
    }
  }

  /// The ad requests are "not child directed" (a university app) and the
  /// content rating is capped at PG.
  Future<void> _applyRequestConfiguration() async {
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        maxAdContentRating: MaxAdContentRating.pg,
        ageRestrictedTreatment: AgeRestrictedTreatment.unspecified,
      ),
    );
  }

  /// UMP (User Messaging Platform). If the AdMob account has a consent
  /// message for the student's region, the form is shown BEFORE any ad is
  /// requested. If there is no message (most students are outside the
  /// EEA/UK), this resolves instantly and nothing is shown.
  Future<void> _collectConsent() async {
    final done = Completer<void>();
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          if (!done.isCompleted) done.complete();
        },
        (FormError error) {
          debugPrint('AdMob: consent info unavailable (${error.errorCode})');
          if (!done.isCompleted) done.complete();
        },
      );
    } catch (e) {
      debugPrint('AdMob: consent request failed ($e)');
      return;
    }
    // Never let a hanging consent request stall the app.
    await done.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () {},
    );
    try {
      if (await ConsentInformation.instance.isConsentFormAvailable()) {
        await ConsentForm.loadAndShowConsentFormIfRequired((error) {
          if (error != null) {
            debugPrint('AdMob: consent form dismissed (${error.errorCode})');
          }
        });
      }
    } catch (e) {
      debugPrint('AdMob: consent form skipped ($e)');
    }
  }

  // ---------------------------------------------------------------- app open

  void _loadAppOpen() {
    try {
      AppOpenAd.load(
        adUnitId: AdMobIds.appOpen,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _appOpen = ad;
          },
          onAdFailedToLoad: (error) {
            debugPrint('AdMob: app open failed to load (${error.code})');
            _appOpen = null;
          },
        ),
      );
    } catch (e) {
      debugPrint('AdMob: app open load threw ($e)');
    }
  }

  /// Shows the app open ad (if one is loaded and the cooldown allows it).
  Future<void> showAppOpen() async {
    if (!ready || _fullScreenBusy) return;
    final ad = _appOpen;
    if (ad == null) {
      _loadAppOpen();
      return;
    }
    if (_lastFullScreenAt != null &&
        DateTime.now().difference(_lastFullScreenAt!) < fullScreenCooldown) {
      return;
    }
    _appOpen = null;
    _fullScreenBusy = true;
    _lastFullScreenAt = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _fullScreenBusy = false;
        _loadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdMob: app open failed to show (${error.code})');
        ad.dispose();
        _fullScreenBusy = false;
      },
    );
    try {
      await ad.show();
    } catch (e) {
      debugPrint('AdMob: app open show threw ($e)');
      _fullScreenBusy = false;
    }
  }

  /// Called when the app goes to the background.
  void onPaused() {
    _pausedAt = DateTime.now();
  }

  /// Called when the app comes back. An app open ad is offered only when
  /// the student was away long enough (no ad on a quick app switch).
  void onResumed() {
    final paused = _pausedAt;
    _pausedAt = null;
    if (!ready || paused == null) return;
    if (DateTime.now().difference(paused) < appOpenResumeThreshold) return;
    unawaited(showAppOpen());
  }

  // ------------------------------------------------------------ interstitial

  void _loadInterstitial() {
    try {
      InterstitialAd.load(
        adUnitId: AdMobIds.interstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitial = ad;
          },
          onAdFailedToLoad: (error) {
            debugPrint('AdMob: interstitial failed to load (${error.code})');
            _interstitial = null;
          },
        ),
      );
    } catch (e) {
      debugPrint('AdMob: interstitial load threw ($e)');
    }
  }

  /// Shows an interstitial at a natural transition (Home -> a section).
  /// The very first transition is ad-free and cooldowns apply.
  Future<void> showInterstitial() async {
    if (!ready || _fullScreenBusy) return;
    _sectionChanges++;
    if (_sectionChanges <= 1) return; // no ad on the first move
    final now = DateTime.now();
    if (_lastInterstitialAt != null &&
        now.difference(_lastInterstitialAt!) < interstitialCooldown) {
      return;
    }
    if (_lastFullScreenAt != null &&
        now.difference(_lastFullScreenAt!) < fullScreenCooldown) {
      return;
    }
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    _fullScreenBusy = true;
    _lastInterstitialAt = now;
    _lastFullScreenAt = now;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _fullScreenBusy = false;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdMob: interstitial failed to show (${error.code})');
        ad.dispose();
        _fullScreenBusy = false;
      },
    );
    try {
      await ad.show();
    } catch (e) {
      debugPrint('AdMob: interstitial show threw ($e)');
      _fullScreenBusy = false;
    }
  }

  // ---------------------------------------------------------------- rewarded

  void _loadRewarded() {
    if (_rewarded != null || _rewardedLoading) return;
    _rewardedLoading = true;
    try {
      RewardedAd.load(
        adUnitId: AdMobIds.rewarded,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedLoading = false;
            _rewarded = ad;
          },
          onAdFailedToLoad: (error) {
            debugPrint('AdMob: rewarded failed to load (${error.code})');
            _rewardedLoading = false;
            _rewarded = null;
          },
        ),
      );
    } catch (e) {
      _rewardedLoading = false;
      debugPrint('AdMob: rewarded load threw ($e)');
    }
  }

  /// Preloads the rewarded ad so the offer can be shown instantly.
  void preloadRewarded() {
    if (ready) _loadRewarded();
  }

  /// Waits up to [timeout] for a rewarded ad to be preloaded, retrying
  /// the load every 400 ms. Returns the ad, or null if none arrived in
  /// time — a brand-new app's first unit usually takes a few seconds.
  Future<RewardedAd?> awaitRewarded(
      {Duration timeout = const Duration(seconds: 12)}) async {
    if (!ready) return null;
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      if (_rewarded != null) return _rewarded;
      _loadRewarded();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    return _rewarded;
  }

  /// Shows a rewarded ad. [onReward] runs ONLY when the student actually
  /// finished the ad (Google: the promised reward must be delivered).
  ///
  /// Waits for the ad to load (retrying briefly) before showing it, so a
  /// cold unit doesn’t surface as a silent “no ad”.
  ///
  /// Returns true when the reward was delivered. A missing ad (no fill) or
  /// a failure returns false — the caller keeps the app fully usable.
  Future<bool> showRewarded({required void Function() onReward}) async {
    if (!ready) return false;
    if (_fullScreenBusy) return false;
    final ad = await awaitRewarded();
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    _fullScreenBusy = true;
    _lastFullScreenAt = DateTime.now();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _fullScreenBusy = false;
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdMob: rewarded failed to show (${error.code})');
        ad.dispose();
        _fullScreenBusy = false;
      },
    );
    try {
      await ad.show(
        onUserEarnedReward: (ad, reward) {
          earned = true;
        },
      );
    } catch (e) {
      debugPrint('AdMob: rewarded show threw ($e)');
      _fullScreenBusy = false;
      return false;
    }
    if (earned) {
      onReward();
      return true;
    }
    return false;
  }
}

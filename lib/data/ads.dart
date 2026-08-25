import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// How the game runs: no status bar, no navigation bar, the whole screen.
///
/// Declared here rather than only at startup because this file is what has to
/// put it back. An ad is the one thing that takes the screen away from the
/// game and hands it to somebody else's layout, and [AdsController] leaves
/// this mode for as long as that lasts. See [_releaseScreen].
const SystemUiMode kGameUiMode = SystemUiMode.immersiveSticky;

/// The ad unit ids, real and test.
///
/// **A debug build never touches a real unit.** Google counts impressions and
/// clicks from a developer's own device against the account, and testing on
/// live units is the single most common way to get an AdMob account suspended
/// for invalid traffic. Every id below is therefore chosen by [kDebugMode],
/// which means the thing being run during development is Google's own test
/// inventory and the thing that ships is the real one. There is no switch to
/// forget to flip.
///
/// The real ids all belong to one AdMob app,
/// `ca-app-pub-8244651657160773~5919462505`, which is registered for a single
/// platform. If the game ships on iOS as well it needs a second AdMob app and
/// a second set of units; the ids here would then have to be chosen by
/// platform the way the test ones already are.
class AdUnits {
  const AdUnits._();

  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIos =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _testRewardedAndroid =
      'ca-app-pub-3940256099942544/5354046379';
  static const String _testRewardedIos =
      'ca-app-pub-3940256099942544/6978759866';

  static bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  static String get banner => kDebugMode
      ? (_isIos ? _testBannerIos : _testBannerAndroid)
      : 'ca-app-pub-8244651657160773/6190925241';

  static String get interstitial => kDebugMode
      ? (_isIos ? _testInterstitialIos : _testInterstitialAndroid)
      : 'ca-app-pub-8244651657160773/5999353558';

  static String get rewarded => kDebugMode
      ? (_isIos ? _testRewardedIos : _testRewardedAndroid)
      : 'ca-app-pub-8244651657160773/3581219560';
}

/// Every ad in the game: the interstitial at a break, and the rewarded one the
/// player chooses to watch for an extra life. Banners are separate, because a
/// banner is a widget rather than something that is shown at a moment.
///
/// The one rule everything here is built around: **an ad may never make the
/// player wait.** One is shown only if it is already loaded and sitting ready;
/// if it is not, the level starts immediately and the next one is fetched in
/// the background. A player on a bad connection gets fewer ads, not a game
/// that hangs on a spinner before every level.
///
/// Every call is guarded. A missing plugin, an unconfigured account or a
/// failed load all end the same way — no ad, and the game carries on.
class AdsController extends ChangeNotifier {
  InterstitialAd? _interstitial;
  RewardedInterstitialAd? _rewarded;
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;
  bool _initialised = false;

  /// True while an ad is on screen, so two breaks arriving close together
  /// cannot stack one on top of the other.
  bool _showing = false;

  /// When the last interstitial was dismissed, so the next one can be made to
  /// wait.
  DateTime? _lastBreak;

  /// The least time between two interstitials.
  ///
  /// Without this there is one at the start of every level and one for every
  /// life lost, and losing a life is the single most common thing that happens
  /// in a runner. Playing badly on a short level therefore produced an ad
  /// roughly every fifteen seconds, which is both miserable and, for a game
  /// listed to an audience that includes children, a policy problem.
  ///
  /// A cap here rather than at each call site on purpose: the call sites are
  /// the honest description of where a break *could* go, and this is the one
  /// place that decides how often one is actually taken.
  static const Duration minimumGap = Duration(seconds: 100);

  /// Test seam: what the controller thinks the time is.
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  /// Whether enough time has passed since the last interstitial.
  bool get _breakIsDue {
    final last = _lastBreak;
    return last == null || clock().difference(last) >= minimumGap;
  }

  /// Test seam: whether the ration would allow a break right now.
  @visibleForTesting
  bool get debugBreakIsDue => _breakIsDue;

  /// Test seam: records a break as having just happened, without an ad and
  /// without a platform to show one on.
  @visibleForTesting
  void debugMarkBreakTaken() => _lastBreak = clock();

  /// Android and iOS are the only platforms the game ships on.
  bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Whether an interstitial is loaded and could be shown right now.
  bool get hasAdReady => _interstitial != null;

  /// Whether an extra life can actually be offered. The button is hidden when
  /// this is false: offering a reward the game cannot deliver is worse than
  /// not offering one.
  ///
  /// False while another ad is on screen, which is not a detail — the out of
  /// lives panel is built underneath the interstitial that plays at the same
  /// moment, so this only becomes true once that one is dismissed. Anything
  /// reading it has to listen as well.
  bool get canOfferExtraLife =>
      debugOfferExtraLife || (_rewarded != null && !_showing);

  /// Test seam: forces [canOfferExtraLife] on without a platform behind it.
  @visibleForTesting
  bool debugOfferExtraLife = false;

  /// Starts the SDK and fetches the first of each. Call once, at start up, and
  /// do not await it: reaching the menu must not wait on a network.
  Future<void> initialize() async {
    if (_initialised || !isSupported) return;
    _initialised = true;
    try {
      await MobileAds.instance.initialize();
      preload();
      preloadRewarded();
    } catch (error) {
      debugPrint('Pitchpole: ads unavailable ($error)');
    }
  }

  /// Fetches the next interstitial, if the slot is empty and nothing is
  /// already in flight.
  void preload() {
    if (!isSupported || _loadingInterstitial || _interstitial != null) return;
    _loadingInterstitial = true;
    unawaited(_loadInterstitial());
  }

  /// Split out and awaited inside its own try, because the load throws
  /// asynchronously when the plugin is missing. Wrapping the un-awaited call
  /// instead would leave that as an unhandled error rather than a caught one.
  Future<void> _loadInterstitial() async {
    try {
      await InterstitialAd.load(
        adUnitId: AdUnits.interstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _loadingInterstitial = false;
            _interstitial = ad;
          },
          onAdFailedToLoad: (error) {
            _loadingInterstitial = false;
            // Not retried on a timer. The next break calls preload again,
            // which is a natural backoff: a player who is failing levels asks
            // for one every thirty seconds, and one who is not, rarely.
            debugPrint('Pitchpole: no ad to show (${error.code})');
          },
        ),
      );
    } catch (error) {
      _loadingInterstitial = false;
      debugPrint('Pitchpole: ads unavailable ($error)');
    }
  }

  void preloadRewarded() {
    if (!isSupported || _loadingRewarded || _rewarded != null) return;
    _loadingRewarded = true;
    unawaited(_loadRewarded());
  }

  Future<void> _loadRewarded() async {
    try {
      await RewardedInterstitialAd.load(
        adUnitId: AdUnits.rewarded,
        request: const AdRequest(),
        rewardedInterstitialAdLoadCallback:
            RewardedInterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _loadingRewarded = false;
            _rewarded = ad;
            // The out of lives panel decides whether to offer an extra life
            // from this, and it may already be on screen when the ad lands.
            notifyListeners();
          },
          onAdFailedToLoad: (error) {
            _loadingRewarded = false;
            debugPrint('Pitchpole: no rewarded ad (${error.code})');
            notifyListeners();
          },
        ),
      );
    } catch (error) {
      _loadingRewarded = false;
      debugPrint('Pitchpole: ads unavailable ($error)');
    }
  }

  /// Shows an interstitial if one is ready, and returns once the player is
  /// back in the game. Returns whether anything was actually shown.
  ///
  /// Returns immediately, with false, when there is nothing loaded. Callers
  /// can await this unconditionally and carry on either way.
  Future<bool> showAtBreak() async {
    if (!isSupported || _showing) return false;

    // Too soon after the last one. The loaded ad is kept rather than burnt, so
    // the next break that is actually due still has something to show.
    if (!_breakIsDue) return false;

    final ad = _interstitial;
    if (ad == null) {
      // Nothing to show, so nothing to wait for. Line one up for next time.
      preload();
      return false;
    }
    _interstitial = null;
    _showing = true;
    await _releaseScreen();
    // Announced both ways round. The out of lives panel is built while this
    // interstitial is still up, and [canOfferExtraLife] is false for as long
    // as it is — so without telling anyone when it closes, that panel never
    // re-checks and the extra life is never offered at all.
    notifyListeners();

    final closed = Completer<void>();
    void finish(InterstitialAd shown) {
      shown.dispose();
      _showing = false;
      unawaited(_reclaimScreen());
      // Timed from when it closed rather than from when it opened, so a long
      // ad does not eat into the quiet that is supposed to follow it.
      _lastBreak = clock();
      preload();
      notifyListeners();
      if (!closed.isCompleted) closed.complete();
    }

    try {
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: finish,
        onAdFailedToShowFullScreenContent: (shown, error) {
          debugPrint('Pitchpole: ad failed to show ($error)');
          finish(shown);
        },
      );
      await ad.show();
      await closed.future;
      return true;
    } catch (error) {
      debugPrint('Pitchpole: ad failed to show ($error)');
      _showing = false;
      unawaited(_reclaimScreen());
      preload();
      notifyListeners();
      return false;
    }
  }

  /// Plays the rewarded ad and reports whether the player earned the reward.
  ///
  /// False covers everything: no ad loaded, the ad failed, or the player
  /// closed it early. The caller must treat all of those the same and grant
  /// nothing — but must also never punish the player for it, since a failed
  /// ad is not their doing.
  Future<bool> showForExtraLife() async {
    if (!isSupported || _showing) return false;

    final ad = _rewarded;
    if (ad == null) {
      preloadRewarded();
      return false;
    }
    _rewarded = null;
    _showing = true;
    await _releaseScreen();
    notifyListeners();

    var earned = false;
    final closed = Completer<void>();
    void finish(RewardedInterstitialAd shown) {
      shown.dispose();
      _showing = false;
      unawaited(_reclaimScreen());
      preloadRewarded();
      notifyListeners();
      if (!closed.isCompleted) closed.complete();
    }

    try {
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: finish,
        onAdFailedToShowFullScreenContent: (shown, error) {
          debugPrint('Pitchpole: rewarded ad failed to show ($error)');
          finish(shown);
        },
      );
      // Only this callback grants the life. Dismissing the ad early never
      // reaches it, which is the whole contract of a rewarded ad.
      await ad.show(onUserEarnedReward: (ad, reward) => earned = true);
      await closed.future;
      return earned;
    } catch (error) {
      debugPrint('Pitchpole: rewarded ad failed to show ($error)');
      _showing = false;
      unawaited(_reclaimScreen());
      preloadRewarded();
      notifyListeners();
      return false;
    }
  }

  /// Test seam: pretends an ad is on screen without a platform behind it.
  @visibleForTesting
  set debugShowing(bool value) => _showing = value;

  /// Gives the system bars back for as long as an ad is on screen.
  ///
  /// The Mobile Ads SDK opens its own activity and copies the host's system UI
  /// visibility onto it, so the game's immersive sticky mode lands on the ad's
  /// window. `dumpsys window` on a stuck ad showed exactly that:
  ///
  ///     com.portalcrafter.pitchpole/...ads.AdActivity
  ///       vsysui=HIDE_NAVIGATION IMMERSIVE_STICKY
  ///       fl=LAYOUT_IN_SCREEN FULLSCREEN
  ///       layoutInDisplayCutoutMode=always
  ///       fitSides=
  ///
  /// An ad laid out edge to edge with no insets puts its own chrome — the
  /// countdown, and the close button with it — outside the usable screen, and
  /// a player who cannot close an ad cannot play. The creative decides how
  /// badly that lands, which is why some ads closed fine and one trapped the
  /// screen for ninety seconds.
  ///
  /// Fails soft like everything else here: a platform with no window to
  /// change is not the player's problem.
  Future<void> _releaseScreen() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    } catch (error) {
      debugPrint('Pitchpole: could not show the system bars ($error)');
    }
  }

  /// Takes the screen back once the ad is gone.
  Future<void> _reclaimScreen() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(kGameUiMode);
    } catch (error) {
      debugPrint('Pitchpole: could not restore immersive mode ($error)');
    }
  }
}

final AdsController adsController = AdsController();

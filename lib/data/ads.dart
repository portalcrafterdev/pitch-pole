import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Interstitial ads at the two breaks in a run: before a level starts, and
/// when the last life goes.
///
/// The one rule everything here is built around: **an ad may never make the
/// player wait.** One is shown only if it is already loaded and sitting ready;
/// if it is not, the level starts immediately and the next one is fetched in
/// the background. A player on a bad connection gets fewer ads, not a game
/// that hangs on a spinner before every level.
///
/// Every call is guarded. A missing plugin, an unconfigured account or a
/// failed load all end the same way — no ad, and the game carries on.
class AdsController {
  /// Google's own test units. They serve a real ad shaped placeholder to any
  /// device without an AdMob account, which is what makes this testable now.
  ///
  /// **These must be replaced before the game ships.** Real units come from
  /// the AdMob console, one per platform, and the app id in
  /// `android/app/src/main/res/values/ad_ids.xml` and in `Info.plist` has to
  /// be the matching real one. Shipping with these serves test ads to real
  /// players and earns nothing; shipping real units while developing against
  /// them gets the account suspended for invalid traffic.
  static const String _androidTestUnit =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _iosTestUnit = 'ca-app-pub-3940256099942544/4411468910';

  InterstitialAd? _ready;
  bool _loading = false;
  bool _initialised = false;

  /// True while an ad is on screen, so two breaks arriving close together
  /// cannot stack one on top of the other.
  bool _showing = false;

  /// Android and iOS are the only platforms the game ships on.
  bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  String get _unitId => defaultTargetPlatform == TargetPlatform.iOS
      ? _iosTestUnit
      : _androidTestUnit;

  /// Whether an ad is loaded and could be shown right now.
  bool get hasAdReady => _ready != null;

  /// Starts the SDK and fetches the first ad. Call once, at start up, and do
  /// not await it: reaching the menu must not wait on a network.
  Future<void> initialize() async {
    if (_initialised || !isSupported) return;
    _initialised = true;
    try {
      await MobileAds.instance.initialize();
      preload();
    } catch (error) {
      debugPrint('Pitchpole: ads unavailable ($error)');
    }
  }

  /// Fetches the next ad into the slot, if it is empty and nothing is already
  /// in flight.
  void preload() {
    if (!isSupported || _loading || _ready != null) return;
    _loading = true;
    unawaited(_load());
  }

  /// Split out and awaited inside its own try, because the load throws
  /// asynchronously when the plugin is missing. Wrapping the un-awaited call
  /// instead would leave that as an unhandled error rather than a caught one.
  Future<void> _load() async {
    try {
      await InterstitialAd.load(
        adUnitId: _unitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _loading = false;
            _ready = ad;
          },
          onAdFailedToLoad: (error) {
            _loading = false;
            // Not retried on a timer. The next break calls preload again,
            // which is a natural backoff: a player who is failing levels asks
            // for one every thirty seconds, and one who is not, rarely.
            debugPrint('Pitchpole: no ad to show (${error.code})');
          },
        ),
      );
    } catch (error) {
      _loading = false;
      debugPrint('Pitchpole: ads unavailable ($error)');
    }
  }

  /// Shows an ad if one is ready, and returns once the player is back in the
  /// game. Returns whether anything was actually shown.
  ///
  /// Returns immediately, with false, when there is nothing loaded. Callers
  /// can await this unconditionally and carry on either way.
  Future<bool> showAtBreak() async {
    if (!isSupported || _showing) return false;

    final ad = _ready;
    if (ad == null) {
      // Nothing to show, so nothing to wait for. Line one up for next time.
      preload();
      return false;
    }
    _ready = null;
    _showing = true;

    final closed = Completer<void>();
    void finish(InterstitialAd shown) {
      shown.dispose();
      _showing = false;
      preload();
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
      preload();
      return false;
    }
  }

  /// Test seam: pretends an ad is loaded without a platform behind it.
  @visibleForTesting
  set debugShowing(bool value) => _showing = value;
}

final AdsController adsController = AdsController();

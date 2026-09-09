import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/ads.dart';
import '../palette.dart';

/// A banner, for the screens where the player is browsing rather than playing.
///
/// Deliberately never placed over the run. The whole screen is a control in
/// the halves scheme and the pads sit at the bottom corners in the other, so a
/// banner anywhere near the play field is both a misplaced tap waiting to
/// happen and, by Google's own rules, an accidental click they will bill back.
///
/// It takes up no space at all until an ad has actually loaded, so a device
/// with no ads to serve gets a full height grid rather than an empty strip.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> with WidgetsBindingObserver {
  BannerAd? _banner;
  bool _loaded = false;

  /// How many first loads have come back empty, and the timer waiting to try
  /// again.
  ///
  /// No fill is not a failure, it is an answer: there was no ad to give right
  /// now. It happens most on the level select, because the home screen is
  /// still sitting underneath it in the navigator with a banner of its own, so
  /// the two ask for the same unit at once and the second is declined. One
  /// declined request used to mean an empty strip for the whole visit.
  int _attempts = 0;
  Timer? _retry;

  /// Backed off, and capped. Five tries over about two and a half minutes is
  /// long enough to outlast the reason a request was declined, and short
  /// enough that a device with nothing to serve is not asked all day.
  static const List<Duration> _backoff = [
    Duration(seconds: 4),
    Duration(seconds: 10),
    Duration(seconds: 25),
    Duration(seconds: 55),
    Duration(seconds: 90),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }


  /// Tries again when the app comes back to the front.
  ///
  /// A phone locked with the game open, or switched away from and back, can
  /// return with no ad: the request that was in flight was declined while
  /// nothing was on screen, and the retries ran out in the background. The
  /// backoff is reset here rather than continued, because coming back is new
  /// information — the reason the last request was refused may have passed
  /// while the screen was off.
  ///
  /// Only when there is nothing to show. A banner that survived is left
  /// exactly as it is, so unlocking a phone never costs a fresh request for a
  /// slot that is already filled.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_banner != null && _loaded) return;
    _attempts = 0;
    _load();
  }

  void _load() {
    // One request in flight at a time. A resume landing on top of a pending
    // retry would otherwise leave two ads loading into one slot, and the
    // loser of that race is an ad nobody ever sees and an impression the
    // account is still asked to account for.
    if (!adsController.isSupported || _banner != null) return;
    _retry?.cancel();
    try {
      final banner = BannerAd(
        adUnitId: AdUnits.banner,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            // The budget is spent per outage, not per session. A banner that
            // filled and later stops has its own five tries rather than
            // inheriting whatever was left over from the last time.
            _attempts = 0;
            if (mounted) setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('Pitchpole: no banner (${error.code})');

            // A banner unit refreshes itself on a timer, and every refresh is
            // a fresh request against the same ad. A refresh that finds no
            // fill is reported here — the same callback a first load that
            // failed comes through — so treating it as fatal threw away a
            // banner that was working and left the strip empty for the rest
            // of the session. Which is exactly what it did: the ad appeared,
            // and about a minute later it was gone for good.
            //
            // One that has loaded at least once is kept. The SDK tries again
            // on its next cycle and what is on screen stays until it wins.
            if (_loaded) return;

            // Cleared before it is disposed, so [dispose] below does not
            // reach for an ad that has already been thrown away.
            _banner = null;
            ad.dispose();
            if (mounted) setState(() {});
            _scheduleRetry();
          },
        ),
      );
      _banner = banner;
      // Caught on the future as well as around it. [BannerAd.load] reports a
      // missing or unconfigured plugin by throwing *asynchronously*, which the
      // try below never sees, so the failure escaped as an unhandled error
      // instead of quietly leaving the page with no banner. Same rule as the
      // rest of ads.dart: every path fails silently and costs the player
      // nothing.
      unawaited(banner.load().catchError((Object error) {
        debugPrint('Pitchpole: no banner ($error)');
        if (_loaded) return;
        _banner = null;
        if (mounted) setState(() {});
        _scheduleRetry();
      }));
    } catch (error) {
      debugPrint('Pitchpole: ads unavailable ($error)');
      _banner = null;
    }
  }

  void _scheduleRetry() {
    if (!mounted || _attempts >= _backoff.length) return;
    _retry?.cancel();
    _retry = Timer(_backoff[_attempts++], () {
      if (mounted && _banner == null) _load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retry?.cancel();
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    if (banner == null || !_loaded) return const SizedBox.shrink();

    // The colour goes outside the [SafeArea], not inside it.
    //
    // The other way round, the inset a landscape phone keeps at its left edge
    // for a cutout or a gesture area fell outside the painted box, so the page
    // behind showed through as a pale strip at the start of an otherwise dark
    // bar. The surface now runs the full width and the safe area only decides
    // where the ad itself may sit inside it.
    return ColoredBox(
      color: Palette.background,
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: banner.size.height.toDouble(),
          child: Center(
            child: SizedBox(
              width: banner.size.width.toDouble(),
              height: banner.size.height.toDouble(),
              child: AdWidget(ad: banner),
            ),
          ),
        ),
      ),
    );
  }
}

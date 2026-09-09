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

class _AdBannerState extends State<AdBanner> {
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (!adsController.isSupported) return;
    try {
      final banner = BannerAd(
        adUnitId: AdUnits.banner,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted) setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('Pitchpole: no banner (${error.code})');
            ad.dispose();
            if (mounted) setState(() => _banner = null);
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
        if (mounted) setState(() => _banner = null);
      }));
    } catch (error) {
      debugPrint('Pitchpole: ads unavailable ($error)');
      _banner = null;
    }
  }

  @override
  void dispose() {
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

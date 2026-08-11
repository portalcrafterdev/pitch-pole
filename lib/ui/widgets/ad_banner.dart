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
      banner.load();
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

    return SafeArea(
      top: false,
      child: Container(
        color: Palette.background,
        width: double.infinity,
        height: banner.size.height.toDouble(),
        alignment: Alignment.center,
        child: SizedBox(
          width: banner.size.width.toDouble(),
          height: banner.size.height.toDouble(),
          child: AdWidget(ad: banner),
        ),
      ),
    );
  }
}

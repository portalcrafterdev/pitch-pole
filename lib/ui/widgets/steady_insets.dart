import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Holds every screen to the insets it has with the system bars hidden.
///
/// `main.dart` puts Android in [SystemUiMode.immersiveSticky], so the status
/// and navigation bars are normally gone and the padding around a page is
/// nothing but the display cutout. They come back on their own, though: a
/// swipe from an edge shows them for a few seconds, and raising the soft
/// keyboard brings them back for as long as it is up. In landscape that is a
/// navigation bar down one edge worth about forty eight points.
///
/// Flutter reports that honestly, [SafeArea] honours it, and everything
/// underneath relayouts — which on the level select meant every tile in the
/// grid rebuilding some eight percent smaller and back again a moment later.
/// Nothing was wrong with any of it; the page was simply answering a question
/// it should not have been asked, because in immersive mode a bar that shows
/// itself is an overlay, not a change to the room.
///
/// So the least padding seen at this size is what gets handed down. Least
/// rather than latest, because the bars can only ever add to it: the steady
/// state is the smallest reading, and a transient one is always larger.
///
/// It is not thrown away, only ignored while it lasts. A bar drawn over the
/// rightmost column of tiles for three seconds is what immersive means; a grid
/// that resizes twice in those three seconds is a bug.
class SteadyInsets extends StatefulWidget {
  const SteadyInsets({super.key, required this.child});

  final Widget child;

  /// Drop in for [MaterialApp.builder], so the app and the tests wrap their
  /// screens through one definition rather than two that have to agree.
  static Widget wrap(BuildContext context, Widget? child) =>
      SteadyInsets(child: child ?? const SizedBox.shrink());

  @override
  State<SteadyInsets> createState() => _SteadyInsetsState();
}

class _SteadyInsetsState extends State<SteadyInsets> {
  Size? _size;
  EdgeInsets _least = EdgeInsets.zero;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    // Learned per size, and forgotten when it changes. The game is landscape
    // both ways round, so a rotation moves a cutout from one edge to the
    // other: what was true of the old orientation says nothing about the new
    // one, and carrying a zero across would swallow a real notch.
    if (_size != media.size) {
      _size = media.size;
      _least = media.padding;
    } else {
      _least = EdgeInsets.only(
        left: math.min(_least.left, media.padding.left),
        top: math.min(_least.top, media.padding.top),
        right: math.min(_least.right, media.padding.right),
        bottom: math.min(_least.bottom, media.padding.bottom),
      );
    }

    // `viewInsets` is deliberately left alone. That is the keyboard, and a
    // dialog has to keep being able to lift itself clear of it.
    return MediaQuery(
      data: media.copyWith(padding: _least, viewPadding: _least),
      child: widget.child,
    );
  }
}

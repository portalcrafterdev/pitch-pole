/// Constants and integration helpers, in design units.
///
/// This file must never import Flame, Flutter or dart:ui. It is unit tested
/// directly and reused by the headless level simulator.
///
/// The numbers here are taken from a working prototype. Do not change them
/// without replaying the tuning pass.
library;

import 'dart:math';

/// Fixed virtual canvas. Everything is authored against this and letterboxed
/// onto the device.
const double kCanvasWidth = 560;
const double kCanvasHeight = 220;

/// Top of the floor blocks. The character rests with its bottom on this line.
const double kFloorSurfaceY = 170;

/// Bottom of the ceiling blocks. The character rests with its top on this line.
const double kCeilingSurfaceY = 50;

const double kBandHeight = kFloorSurfaceY - kCeilingSurfaceY;
const double kBlockThickness = 16;

const double kPlayerSize = 22;

/// The character never moves horizontally on screen. The world moves past it.
const double kPlayerScreenX = 90;

const double kRunSpeed = 200;
const double kPlayerGravity = 2600;
const double kJumpVelocity = 560;

/// Small nudge on flip so the fall starts instantly instead of drifting.
const double kFlipImpulse = 60;

const double kEnemyGravity = 1500;
const double kHopVelocity = 520;
const double kHopPeriod = 1.75;
const double kLevelLength = 6000;

/// Every level is this many seconds of running.
const double kLevelSeconds = 30;

/// The simulation always advances in this step, whatever the frame rate.
const double kFixedStep = 1 / 120;

/// Hit boxes come in this far on every side from the drawn sprite. Generous
/// hit boxes make a fast runner feel unfair.
const double kHitboxShrink = 3;

const double kBoltedWidth = 28;
const double kBoltedHeight = 30;
const double kHopperSize = 26;

/// A blade sweeps the whole band, so the safe moment is whenever it is at the
/// surface you are not on.
const double kBladeWidth = 26;
const double kBladeHeight = 10;
const double kBladePeriod = 1.9;

/// A stone rests against its surface, slams across the band, and is winched
/// back up.
const double kStoneSize = 24;
const double kStonePeriod = 2.4;
const double kStoneFallTime = 0.30;
const double kStoneHoldTime = 0.20;
const double kStoneRiseTime = 0.60;

/// How long one slam takes, start to back home.
const double kStoneCycleTime = kStoneFallTime + kStoneHoldTime + kStoneRiseTime;

/// How far a stone travels from its own surface at full extension.
const double kStoneReach = kBandHeight - kStoneSize;

/// A fire vent sits flush with one surface, dark, and then erupts. It reaches
/// higher than the character can jump, so the only answer is the other
/// surface — but only while it is lit. That is what separates it from a
/// bolted enemy: a bolted forces a flip, a fire forces a flip *now*.
const double kFireWidth = 22;

/// How far a flame reaches from its own surface at full height. Above the
/// 60 unit jump peak so it cannot be hopped, and far enough below the 120
/// unit band that the opposite surface stays clear.
const double kFireReach = 70;

const double kFirePeriod = 2.6;

/// The vent glows for this long before anything comes out. This is the tell,
/// and it is why a fire is readable rather than a trap.
const double kFireWarnTime = 0.45;

const double kFireRiseTime = 0.18;
const double kFireHoldTime = 0.45;
const double kFireFallTime = 0.30;

/// How long the flame is out for, from first spark to gone.
const double kFireBurnTime = kFireRiseTime + kFireHoldTime + kFireFallTime;

/// One full warning and burn. A vent's period has to be longer than this.
const double kFireCycleTime = kFireWarnTime + kFireBurnTime;

/// A bat hangs in the middle of the band and drifts. It never comes near
/// either surface, so a character that stays put is always safe.
///
/// It is the only obstacle that punishes leaving a surface. Every other one is
/// answered by flipping or jumping; a bat closes both, because a flip crosses
/// the band and a jump peaks inside it. The answer is to already be where you
/// mean to be, which is a decision the player has to make *before* arriving.
const double kBatWidth = 28;
const double kBatHeight = 22;
const double kBatPeriod = 2.2;

/// Middle of the band, where a bat hovers.
const double kBatCentreY = (kCeilingSurfaceY + kFloorSurfaceY) / 2;

/// How far a bat drifts either side of the middle. Small enough that the
/// margin to a resting character never closes.
const double kBatDrift = 10;

/// A spider drops out of the canopy on a thread, hangs, and climbs back.
///
/// While it is moving it sweeps the ceiling; while it hangs it closes the
/// middle. So it shuts the ceiling and then the air, in that order, and the
/// floor is never blocked. The descent is slow on purpose: unlike a fire it
/// carries its own warning, because you watch it coming down.
const double kSpiderSize = 24;
const double kSpiderPeriod = 3.4;

/// How far a spider's top gets below the ceiling line at full extension.
/// Deep enough to close the middle, short of the floor so there is always
/// somewhere to stand.
const double kSpiderReach = 62;

/// Where a spider sits when it is not out: fully tucked up into the canopy,
/// clear of the band, so a resting spider cannot kill anything.
const double kSpiderRest = -kSpiderSize;

const double kSpiderDropTime = 0.9;
const double kSpiderHangTime = 0.6;
const double kSpiderClimbTime = 0.8;

/// One full drop, hang and climb. A spider's period has to be longer.
const double kSpiderCycleTime =
    kSpiderDropTime + kSpiderHangTime + kSpiderClimbTime;

/// A coin sitting in the run, to be collected on the way past.
///
/// Coins never kill and never block, so they are the one box in the game that
/// is *grown* rather than shrunk. The 3 unit shrink on everything else exists
/// because a generous lethal box feels unfair; a generous reward box feels
/// good, so the rule is inverted here on purpose.
const double kCoinSize = 14;
const double kCoinReach = 3;

/// Cosmetic only. Never part of the hit box.
const double kBoltedBob = 1.5;

/// How long one hop keeps a hopper off its surface.
const double kHopAirTime = 2 * kHopVelocity / kEnemyGravity;

/// Peak of one hop, above the hopper's own surface.
const double kHopPeak = kHopVelocity * kHopVelocity / (2 * kEnemyGravity);

/// Peak of the character's jump, above the surface it left.
const double kJumpPeak = kJumpVelocity * kJumpVelocity / (2 * kPlayerGravity);

/// Which way is down for the character right now.
double gravityFor({required bool gravityUp}) =>
    gravityUp ? -kPlayerGravity : kPlayerGravity;

/// Top edge of the character when it is resting on a surface.
double restingY({required bool gravityUp}) =>
    gravityUp ? kCeilingSurfaceY : kFloorSurfaceY - kPlayerSize;

/// The character's top edge can never leave this range.
const double kMinPlayerY = kCeilingSurfaceY;
const double kMaxPlayerY = kFloorSurfaceY - kPlayerSize;

/// Height of a hopper above its own surface, [cycleTime] seconds into its
/// cycle. Zero while it is resting.
double hopHeightAt(double cycleTime) {
  if (cycleTime < 0 || cycleTime >= kHopAirTime) return 0;
  final height =
      kHopVelocity * cycleTime - 0.5 * kEnemyGravity * cycleTime * cycleTime;
  return height > 0 ? height : 0;
}

/// An axis aligned box, so collision stays pure Dart.
class Box {
  const Box(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  bool overlaps(Box other) =>
      left < other.right &&
      other.left < right &&
      top < other.bottom &&
      other.top < bottom;

  /// Pulls every edge in by [amount].
  Box deflate(double amount) => Box(
        left + amount,
        top + amount,
        width - amount * 2,
        height - amount * 2,
      );

  @override
  String toString() =>
      'Box(${left.toStringAsFixed(1)}, ${top.toStringAsFixed(1)}, '
      '${width.toStringAsFixed(1)}x${height.toStringAsFixed(1)})';
}

/// The character's drawn box. [x] is its left edge in world units.
Box playerBox(double x, double y) => Box(x, y, kPlayerSize, kPlayerSize);

/// A bolted enemy's drawn box. [x] is its centre in world units.
Box boltedBox(double x, {required bool onCeiling}) => Box(
      x - kBoltedWidth / 2,
      onCeiling ? kCeilingSurfaceY : kFloorSurfaceY - kBoltedHeight,
      kBoltedWidth,
      kBoltedHeight,
    );

/// Where a blade sits in its sweep: 0 at the ceiling, 1 at the floor.
///
/// A cosine rather than a triangle, so it lingers at each end. That lingering
/// is the window the player runs through.
double bladeSweepAt(double cycleTime, double period) {
  final t = (cycleTime % period) / period;
  return (1 - cos(2 * pi * t)) / 2;
}

/// Top edge of a blade [cycleTime] seconds into its sweep.
double bladeTopAt(double cycleTime, double period) =>
    kCeilingSurfaceY +
    (kBandHeight - kBladeHeight) * bladeSweepAt(cycleTime, period);

/// How far a stone has slammed away from its own surface. Zero while it rests.
double stoneOffsetAt(double cycleTime, double period) {
  final cycle = cycleTime % period;
  if (cycle < kStoneFallTime) {
    // Accelerating, so it reads as dropped rather than driven.
    final t = cycle / kStoneFallTime;
    return kStoneReach * t * t;
  }
  if (cycle < kStoneFallTime + kStoneHoldTime) return kStoneReach;
  if (cycle < kStoneCycleTime) {
    final t = (cycle - kStoneFallTime - kStoneHoldTime) / kStoneRiseTime;
    return kStoneReach * (1 - t);
  }
  return 0;
}

/// A blade's drawn box. [x] is its centre in world units.
Box bladeBox(double x, double top) =>
    Box(x - kBladeWidth / 2, top, kBladeWidth, kBladeHeight);

/// A stone's drawn box at [offset] from its own surface. [x] is its centre.
Box stoneBox(double x, {required bool onCeiling, required double offset}) =>
    Box(
      x - kStoneSize / 2,
      onCeiling
          ? kCeilingSurfaceY + offset
          : kFloorSurfaceY - offset - kStoneSize,
      kStoneSize,
      kStoneSize,
    );

/// How far a flame reaches from its own surface, [cycleTime] seconds into its
/// cycle. Zero while the vent is dark, including the whole warning.
double fireHeightAt(double cycleTime, double period) {
  final cycle = cycleTime % period;
  if (cycle < kFireWarnTime) return 0;

  final burn = cycle - kFireWarnTime;
  if (burn < kFireRiseTime) return kFireReach * (burn / kFireRiseTime);
  if (burn < kFireRiseTime + kFireHoldTime) return kFireReach;
  if (burn < kFireBurnTime) {
    final t = (burn - kFireRiseTime - kFireHoldTime) / kFireFallTime;
    return kFireReach * (1 - t);
  }
  return 0;
}

/// 0 to 1 across the warning, then 0 once it is alight. Drives the glow the
/// player reads on approach, and nothing else.
double fireWarningAt(double cycleTime, double period) {
  final cycle = cycleTime % period;
  return cycle < kFireWarnTime ? cycle / kFireWarnTime : 0;
}

/// A flame's box at [height] above its own surface. [x] is its centre. The
/// box is the flame itself, so a dark vent cannot kill anything.
Box fireBox(double x, {required bool onCeiling, required double height}) => Box(
      x - kFireWidth / 2,
      onCeiling ? kCeilingSurfaceY : kFloorSurfaceY - height,
      kFireWidth,
      height,
    );

/// A coin's box. [x] and [y] are its centre, unlike every obstacle, because a
/// coin sits wherever the character passed rather than on a surface.
Box coinBox(double x, double y) => Box(
      x - kCoinSize / 2,
      y - kCoinSize / 2,
      kCoinSize,
      kCoinSize,
    );

/// Where a bat's centre sits, [cycleTime] seconds into its drift.
double batCentreAt(double cycleTime, double period) =>
    kBatCentreY + kBatDrift * sin(2 * pi * (cycleTime % period) / period);

/// A bat's drawn box around [centreY]. [x] is its centre.
Box batBox(double x, double centreY) => Box(
      x - kBatWidth / 2,
      centreY - kBatHeight / 2,
      kBatWidth,
      kBatHeight,
    );

/// How far a spider's top is below the ceiling line, [cycleTime] seconds into
/// its cycle. Negative while it is tucked up in the canopy.
double spiderDropAt(double cycleTime, double period) {
  final cycle = cycleTime % period;

  if (cycle < kSpiderDropTime) {
    // Smoothstepped, so it eases out of the canopy and settles rather than
    // dropping like a stone. A spider is the readable one.
    final t = cycle / kSpiderDropTime;
    return kSpiderRest +
        (kSpiderReach - kSpiderRest) * t * t * (3 - 2 * t);
  }
  if (cycle < kSpiderDropTime + kSpiderHangTime) return kSpiderReach;
  if (cycle < kSpiderCycleTime) {
    final t = (cycle - kSpiderDropTime - kSpiderHangTime) / kSpiderClimbTime;
    return kSpiderRest + (kSpiderReach - kSpiderRest) * (1 - t);
  }
  return kSpiderRest;
}

/// A spider's drawn box at [drop] below the ceiling line. [x] is its centre.
Box spiderBox(double x, double drop) => Box(
      x - kSpiderSize / 2,
      kCeilingSurfaceY + drop,
      kSpiderSize,
      kSpiderSize,
    );

/// A hopper's drawn box at [height] above its own surface. [x] is its centre.
Box hopperBox(double x, {required bool onCeiling, required double height}) =>
    Box(
      x - kHopperSize / 2,
      onCeiling
          ? kCeilingSurfaceY + height
          : kFloorSurfaceY - height - kHopperSize,
      kHopperSize,
      kHopperSize,
    );

/// Pure level data. No Flame, no Flutter, no dart:ui.
///
/// Levels are data only. Nothing here decides how a level plays.
library;

import 'physics.dart';

enum Surface {
  floor,
  ceiling;

  bool get isCeiling => this == Surface.ceiling;

  String get json => name;

  static Surface fromJson(Object? value) =>
      value == 'ceiling' ? Surface.ceiling : Surface.floor;
}

/// Fixed to one surface for the whole level. Forces a flip.
class Bolted {
  const Bolted({required this.x, required this.surface});

  /// Centre of the enemy, in world units.
  final double x;
  final Surface surface;

  Box get box => boltedBox(x, onCeiling: surface.isCeiling);

  factory Bolted.fromJson(Map<String, dynamic> json) => Bolted(
        x: (json['x'] as num).toDouble(),
        surface: Surface.fromJson(json['surface']),
      );

  Map<String, dynamic> toJson() => {'x': x, 'surface': surface.json};
}

/// Anchored to one surface but bouncing on a fixed rhythm.
class Hopper {
  const Hopper({required this.x, required this.surface, this.phase = 0});

  /// Centre of the enemy, in world units.
  final double x;
  final Surface surface;

  /// Offset into the hop cycle, in seconds, so a row of hoppers is not
  /// synchronised.
  final double phase;

  /// Height above its own surface at [levelTime] seconds into the level.
  double heightAt(double levelTime, double hopPeriod) {
    final cycle = (levelTime + phase) % hopPeriod;
    return hopHeightAt(cycle);
  }

  Box boxAt(double levelTime, double hopPeriod) => hopperBox(
        x,
        onCeiling: surface.isCeiling,
        height: heightAt(levelTime, hopPeriod),
      );

  factory Hopper.fromJson(Map<String, dynamic> json) => Hopper(
        x: (json['x'] as num).toDouble(),
        surface: Surface.fromJson(json['surface']),
        phase: (json['phase'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() =>
      {'x': x, 'surface': surface.json, 'phase': phase};
}

/// Sweeps the whole band on its own period. There is no surface to hide on,
/// only a moment when it is far enough away.
class Blade {
  const Blade({required this.x, this.period = kBladePeriod, this.phase = 0});

  /// Centre of the blade, in world units.
  final double x;

  /// Seconds for one full sweep down and back.
  final double period;

  /// Offset into the sweep, in seconds.
  final double phase;

  double topAt(double levelTime) => bladeTopAt(levelTime + phase, period);

  Box boxAt(double levelTime) => bladeBox(x, topAt(levelTime));

  factory Blade.fromJson(Map<String, dynamic> json) => Blade(
        x: (json['x'] as num).toDouble(),
        period: (json['period'] as num?)?.toDouble() ?? kBladePeriod,
        phase: (json['phase'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {'x': x, 'period': period, 'phase': phase};
}

/// Hangs against a surface, slams across the band, and is winched back.
class Stone {
  const Stone({
    required this.x,
    required this.surface,
    this.period = kStonePeriod,
    this.phase = 0,
  });

  /// Centre of the stone, in world units.
  final double x;

  /// The surface it hangs from.
  final Surface surface;

  final double period;
  final double phase;

  double offsetAt(double levelTime) => stoneOffsetAt(levelTime + phase, period);

  Box boxAt(double levelTime) => stoneBox(
        x,
        onCeiling: surface.isCeiling,
        offset: offsetAt(levelTime),
      );

  factory Stone.fromJson(Map<String, dynamic> json) => Stone(
        x: (json['x'] as num).toDouble(),
        surface: Surface.fromJson(json['surface']),
        period: (json['period'] as num?)?.toDouble() ?? kStonePeriod,
        phase: (json['phase'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'x': x,
        'surface': surface.json,
        'period': period,
        'phase': phase,
      };
}

/// A vent flush with one surface that erupts on a rhythm. It reaches higher
/// than a jump, so it has to be flipped away from, but only while it is lit.
class Fire {
  const Fire({
    required this.x,
    required this.surface,
    this.period = kFirePeriod,
    this.phase = 0,
  });

  /// Centre of the vent, in world units.
  final double x;

  /// The surface it is set into.
  final Surface surface;

  final double period;
  final double phase;

  /// How far the flame reaches right now. Zero while the vent is dark.
  double heightAt(double levelTime) => fireHeightAt(levelTime + phase, period);

  /// How far through the warning glow it is. Cosmetic only.
  double warningAt(double levelTime) =>
      fireWarningAt(levelTime + phase, period);

  Box boxAt(double levelTime) => fireBox(
        x,
        onCeiling: surface.isCeiling,
        height: heightAt(levelTime),
      );

  factory Fire.fromJson(Map<String, dynamic> json) => Fire(
        x: (json['x'] as num).toDouble(),
        surface: Surface.fromJson(json['surface']),
        period: (json['period'] as num?)?.toDouble() ?? kFirePeriod,
        phase: (json['phase'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'x': x,
        'surface': surface.json,
        'period': period,
        'phase': phase,
      };
}

/// Hovers in the middle of the band, belonging to no surface.
///
/// It cannot be flipped past or jumped over, because both of those put the
/// character in the air where it is. The only answer is to be on the surface
/// you want before you get here, and stay there.
class Bat {
  const Bat({required this.x, this.period = kBatPeriod, this.phase = 0});

  /// Centre of the bat, in world units.
  final double x;

  /// Seconds for one full drift up and back.
  final double period;

  final double phase;

  double centreAt(double levelTime) => batCentreAt(levelTime + phase, period);

  Box boxAt(double levelTime) => batBox(x, centreAt(levelTime));

  factory Bat.fromJson(Map<String, dynamic> json) => Bat(
        x: (json['x'] as num).toDouble(),
        period: (json['period'] as num?)?.toDouble() ?? kBatPeriod,
        phase: (json['phase'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {'x': x, 'period': period, 'phase': phase};
}

/// Drops out of the canopy on a thread, hangs, and climbs back.
///
/// Always anchored to the ceiling — there is no floor spider, because the
/// whole point is that the floor stays open.
class Spider {
  const Spider({
    required this.x,
    this.period = kSpiderPeriod,
    this.phase = 0,
  });

  /// Centre of the spider, in world units.
  final double x;

  final double period;
  final double phase;

  /// How far below the ceiling line its top sits. Negative while tucked away.
  double dropAt(double levelTime) => spiderDropAt(levelTime + phase, period);

  Box boxAt(double levelTime) => spiderBox(x, dropAt(levelTime));

  factory Spider.fromJson(Map<String, dynamic> json) => Spider(
        x: (json['x'] as num).toDouble(),
        period: (json['period'] as num?)?.toDouble() ?? kSpiderPeriod,
        phase: (json['phase'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {'x': x, 'period': period, 'phase': phase};
}

/// Something to pick up on the way past. Never kills, never blocks.
///
/// Unlike every obstacle a coin carries its own [y], because coins are placed
/// along the line the level is actually run on rather than against a surface.
class Coin {
  const Coin({required this.x, required this.y});

  /// Centre of the coin, in world units.
  final double x;
  final double y;

  Box get box => coinBox(x, y);

  factory Coin.fromJson(Map<String, dynamic> json) => Coin(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

class LevelModel {
  const LevelModel({
    required this.id,
    required this.length,
    required this.runSpeed,
    required this.hopPeriod,
    this.bolted = const [],
    this.hoppers = const [],
    this.blades = const [],
    this.stones = const [],
    this.fires = const [],
    this.bats = const [],
    this.spiders = const [],
    this.coins = const [],
    this.checkpoints = const [],
  });

  final int id;

  /// World length. The door sits here. Always `runSpeed * kLevelSeconds`.
  final double length;

  final double runSpeed;
  final double hopPeriod;

  final List<Bolted> bolted;
  final List<Hopper> hoppers;
  final List<Blade> blades;
  final List<Stone> stones;
  final List<Fire> fires;
  final List<Bat> bats;
  final List<Spider> spiders;

  /// Collectibles. Deliberately not part of [obstacleCount] or [obstacleXs]:
  /// a coin is not in the way, so it must not count towards spacing rules or
  /// satisfy the no dead track rule.
  final List<Coin> coins;

  /// World positions the character respawns at, in ascending order.
  final List<double> checkpoints;

  /// How long the level takes at its own speed. Always 30 seconds.
  double get seconds => length / runSpeed;

  /// The same level with [coins] laid along it. Coins are worked out after a
  /// level is built, because where they go depends on how it is run.
  LevelModel withCoins(List<Coin> coins) => LevelModel(
        id: id,
        length: length,
        runSpeed: runSpeed,
        hopPeriod: hopPeriod,
        bolted: bolted,
        hoppers: hoppers,
        blades: blades,
        stones: stones,
        fires: fires,
        bats: bats,
        spiders: spiders,
        coins: coins,
        checkpoints: checkpoints,
      );

  /// The last checkpoint at or behind [x], or the start.
  double checkpointBehind(double x) {
    var best = 0.0;
    for (final checkpoint in checkpoints) {
      if (checkpoint <= x && checkpoint > best) best = checkpoint;
    }
    return best;
  }

  factory LevelModel.fromJson(Map<String, dynamic> json) => LevelModel(
        id: json['id'] as int,
        length: (json['length'] as num).toDouble(),
        runSpeed: (json['runSpeed'] as num).toDouble(),
        hopPeriod: (json['hopPeriod'] as num).toDouble(),
        bolted: [
          for (final e in (json['bolted'] as List<dynamic>? ?? const []))
            Bolted.fromJson(e as Map<String, dynamic>),
        ],
        hoppers: [
          for (final e in (json['hoppers'] as List<dynamic>? ?? const []))
            Hopper.fromJson(e as Map<String, dynamic>),
        ],
        blades: [
          for (final e in (json['blades'] as List<dynamic>? ?? const []))
            Blade.fromJson(e as Map<String, dynamic>),
        ],
        stones: [
          for (final e in (json['stones'] as List<dynamic>? ?? const []))
            Stone.fromJson(e as Map<String, dynamic>),
        ],
        fires: [
          for (final e in (json['fires'] as List<dynamic>? ?? const []))
            Fire.fromJson(e as Map<String, dynamic>),
        ],
        bats: [
          for (final e in (json['bats'] as List<dynamic>? ?? const []))
            Bat.fromJson(e as Map<String, dynamic>),
        ],
        spiders: [
          for (final e in (json['spiders'] as List<dynamic>? ?? const []))
            Spider.fromJson(e as Map<String, dynamic>),
        ],
        coins: [
          for (final e in (json['coins'] as List<dynamic>? ?? const []))
            Coin.fromJson(e as Map<String, dynamic>),
        ],
        checkpoints: [
          for (final e in (json['checkpoints'] as List<dynamic>? ?? const []))
            (e as num).toDouble(),
        ],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'length': length,
        'runSpeed': runSpeed,
        'hopPeriod': hopPeriod,
        'bolted': [for (final e in bolted) e.toJson()],
        'hoppers': [for (final e in hoppers) e.toJson()],
        'blades': [for (final e in blades) e.toJson()],
        'stones': [for (final e in stones) e.toJson()],
        'fires': [for (final e in fires) e.toJson()],
        'bats': [for (final e in bats) e.toJson()],
        'spiders': [for (final e in spiders) e.toJson()],
        'coins': [for (final e in coins) e.toJson()],
        'checkpoints': checkpoints,
      };

  /// Everything in the way, of any kind.
  int get obstacleCount =>
      bolted.length +
      hoppers.length +
      blades.length +
      stones.length +
      fires.length +
      bats.length +
      spiders.length;

  /// Where everything sits, of any kind, in ascending order. Used to check
  /// that the level never leaves the player with nothing to do.
  List<double> get obstacleXs => <double>[
        ...bolted.map((e) => e.x),
        ...hoppers.map((e) => e.x),
        ...blades.map((e) => e.x),
        ...stones.map((e) => e.x),
        ...fires.map((e) => e.x),
        ...bats.map((e) => e.x),
        ...spiders.map((e) => e.x),
      ]..sort();

  @override
  String toString() => 'Level $id (${length.round()} units at '
      '${runSpeed.round()}/s, ${bolted.length} bolted, '
      '${hoppers.length} hoppers, ${blades.length} blades, '
      '${stones.length} stones, ${fires.length} fires, '
      '${bats.length} bats, ${spiders.length} spiders)';
}

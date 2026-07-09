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

  /// World positions the character respawns at, in ascending order.
  final List<double> checkpoints;

  /// How long the level takes at its own speed. Always 30 seconds.
  double get seconds => length / runSpeed;

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
        'checkpoints': checkpoints,
      };

  /// Everything in the way, of any kind.
  int get obstacleCount =>
      bolted.length + hoppers.length + blades.length + stones.length;

  /// Where everything sits, of any kind, in ascending order. Used to check
  /// that the level never leaves the player with nothing to do.
  List<double> get obstacleXs => <double>[
        ...bolted.map((e) => e.x),
        ...hoppers.map((e) => e.x),
        ...blades.map((e) => e.x),
        ...stones.map((e) => e.x),
      ]..sort();

  @override
  String toString() => 'Level $id (${length.round()} units at '
      '${runSpeed.round()}/s, ${bolted.length} bolted, '
      '${hoppers.length} hoppers, ${blades.length} blades, '
      '${stones.length} stones)';
}

// Authoring tool. Builds the generated part of the level pack and checks every
// level with the same validator the tests use.
//
//   dart run tool/generate_levels.dart --sample 40   # smoke test, no write
//   dart run tool/generate_levels.dart               # build and write the pack
//
// Levels 1 to 20 are hand placed and are read back out of the existing pack
// untouched. Everything from 21 up is generated from its own id, so the output
// is reproducible: running this twice gives byte identical JSON.
//
// Validating a level means solving it, which costs seconds, so the checking is
// spread across isolates. Exits non zero if any level fails.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:pitchpole/game/logic/level_generator.dart';
import 'package:pitchpole/game/logic/level_model.dart';
import 'package:pitchpole/game/logic/level_simulator.dart';

const String _assetPath = 'assets/levels/levels.json';

/// What one worker gives back.
class _Checked {
  const _Checked(this.id, this.problems, this.actions, this.coins, this.json);

  final int id;
  final List<String> problems;
  final int actions;
  final int coins;

  /// The finished level, coins included. Carried back from the worker so the
  /// writer does not have to solve all fifteen hundred levels a second time.
  final Map<String, dynamic>? json;

  bool get ok => problems.isEmpty;
}

/// Generates one level, validates it, and lays coins along the route the
/// solver proved. Runs in its own isolate, so it takes and returns plain data.
_Checked _check(int id) {
  final level = generateLevel(id);
  final result = validateLevel(level);
  if (!result.ok) return _Checked(id, result.problems, 0, 0, null);

  final withCoins = level.withCoins(coinsFor(level));
  return _Checked(
    id,
    const [],
    result.plan!.actions,
    withCoins.coins.length,
    withCoins.toJson(),
  );
}

/// Runs [job] over [ids], at most [concurrency] at a time.
Future<List<T>> _pool<T>(
  List<int> ids,
  Future<T> Function(int id) job, {
  required int concurrency,
  void Function(int done, int total)? onProgress,
}) async {
  final results = List<T?>.filled(ids.length, null);
  var next = 0;
  var done = 0;

  Future<void> worker() async {
    while (true) {
      final index = next++;
      if (index >= ids.length) return;
      results[index] = await job(ids[index]);
      onProgress?.call(++done, ids.length);
    }
  }

  await Future.wait([
    for (var i = 0; i < concurrency; i++) worker(),
  ]);
  return results.cast<T>();
}

/// Recomputes coins for the pack already on disk, leaving every level's
/// obstacles exactly as they are.
///
/// Coins are worked out without the solver, and they cannot change whether a
/// level is completable, so relaying them does not need the whole pack to be
/// validated again. That turns a half hour job into a couple of seconds.
Future<void> _relayCoins() async {
  final file = File(_assetPath);
  final pack = (jsonDecode(await file.readAsString()) as List<dynamic>)
      .map((e) => LevelModel.fromJson(e as Map<String, dynamic>))
      .map((level) => level.withCoins(coinsFor(level)))
      .toList();

  await file.writeAsString(
    '${const JsonEncoder().convert([for (final l in pack) l.toJson()])}\n',
  );

  final coins = pack.fold(0, (sum, l) => sum + l.coins.length);
  final size = await file.length();
  stdout.writeln('relaid coins on ${pack.length} levels: $coins coins '
      '(${(size / 1024 / 1024).toStringAsFixed(2)} MB)');
  for (final level in pack.take(3)) {
    stdout.writeln('  level ${level.id}: ${level.coins.length} coins');
  }
}

Future<void> main(List<String> args) async {
  if (args.contains('--coins-only')) return _relayCoins();

  final sampleIndex = args.indexOf('--sample');
  final sample = sampleIndex >= 0 && sampleIndex + 1 < args.length
      ? int.parse(args[sampleIndex + 1])
      : 0;
  final verbose = args.contains('--verbose');

  // Leave the machine a couple of cores so the run stays usable.
  final concurrency =
      (Platform.numberOfProcessors - 2).clamp(1, 16);

  final ids = sample > 0
      ? _spread(sample)
      : [for (var id = kFirstGeneratedLevel; id <= kTotalLevels; id++) id];

  stdout.writeln('checking ${ids.length} generated levels '
      'across $concurrency isolates');

  final started = DateTime.now();
  final checked = await _pool<_Checked>(
    ids,
    (id) => Isolate.run(() => _check(id)),
    concurrency: concurrency,
    onProgress: (done, total) {
      if (done % 25 == 0 || done == total) {
        final elapsed = DateTime.now().difference(started);
        stdout.write('\r  $done / $total  '
            '${elapsed.inSeconds}s   ');
      }
    },
  );
  stdout.writeln();

  final failed = checked.where((c) => !c.ok).toList();
  for (final failure in failed.take(25)) {
    stdout.writeln('Level ${failure.id}: ${failure.problems.join('; ')}');
  }
  if (failed.length > 25) {
    stdout.writeln('... and ${failed.length - 25} more');
  }

  if (verbose) {
    for (final c in checked.take(40)) {
      final level = generateLevel(c.id);
      stdout.writeln('Level ${c.id.toString().padLeft(4)}  '
          '${level.length.round()}u  ${level.runSpeed.round()}/s  '
          'hop ${level.hopPeriod.toStringAsFixed(2)}  '
          '${archetypeFor(c.id).name.padRight(13)} '
          '${level.bolted.length}B ${level.hoppers.length}H '
          '${level.blades.length}K ${level.stones.length}S '
          '${level.fires.length}F ${level.bats.length}T '
          '${level.spiders.length}P  '
          '${c.coins.toString().padLeft(2)} coins  '
          '${c.actions} inputs');
    }
  }

  final seconds = DateTime.now().difference(started).inMilliseconds / 1000;
  stdout.writeln('${checked.length - failed.length} of ${checked.length} ok '
      'in ${seconds.toStringAsFixed(1)}s');

  if (failed.isNotEmpty) {
    stdout.writeln('${failed.length} level(s) failed, nothing written');
    exit(1);
  }

  if (sample > 0) {
    stdout.writeln('sample run, nothing written');
    return;
  }

  await _write(checked);
}

/// A spread of ids across the whole pack rather than the first N, so a sample
/// exercises the ramp, the speed steps and every archetype.
List<int> _spread(int count) {
  final span = kTotalLevels - kFirstGeneratedLevel;
  return [
    for (var i = 0; i < count; i++)
      kFirstGeneratedLevel + (span * i / (count - 1)).round(),
  ];
}

Future<void> _write(List<_Checked> checked) async {
  final file = File(_assetPath);
  final existing = (jsonDecode(await file.readAsString()) as List<dynamic>)
      .map((e) => LevelModel.fromJson(e as Map<String, dynamic>))
      .where((level) => level.id < kFirstGeneratedLevel)
      .toList();

  stdout.writeln('keeping ${existing.length} hand placed levels');

  // The taught levels get coins the same way the generated ones do, and are
  // solved as well so a hand placed level can never quietly stop working.
  final taught = <Map<String, dynamic>>[];
  for (final level in existing) {
    if (solveLevel(level) == null) {
      stdout.writeln('level ${level.id} could not be solved, nothing written');
      exit(1);
    }
    final withCoins = level.withCoins(coinsFor(level));
    stdout.writeln('  level ${level.id}: ${withCoins.coins.length} coins');
    taught.add(withCoins.toJson());
  }

  final pack = <Map<String, dynamic>>[
    ...taught,
    for (final c in checked) c.json!,
  ];

  await file.writeAsString('${const JsonEncoder().convert(pack)}\n');

  final coins = checked.fold(0, (sum, c) => sum + c.coins);
  final size = await file.length();
  stdout.writeln('wrote ${pack.length} levels to $_assetPath '
      '(${(size / 1024 / 1024).toStringAsFixed(2)} MB), '
      '$coins coins across the generated levels');
}

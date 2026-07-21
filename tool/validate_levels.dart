// Authoring tool. Runs the headless simulator over every level and reports
// whether it is completable, along with the input sequence the solver found.
//
//   dart run tool/validate_levels.dart
//
// Exits non zero if any level fails, so it doubles as a pre commit check.
// The same validation runs inside test/levels_test.dart.

import 'dart:convert';
import 'dart:io';

import 'package:pitchpole/game/logic/level_model.dart';
import 'package:pitchpole/game/logic/level_simulator.dart';
import 'package:pitchpole/game/logic/physics.dart';

void main(List<String> args) {
  final verbose = args.contains('--verbose');
  final file = File('assets/levels/levels.json');
  final raw = jsonDecode(file.readAsStringSync()) as List<dynamic>;

  var failed = 0;
  final stopwatch = Stopwatch()..start();

  for (final entry in raw) {
    final level = LevelModel.fromJson(entry as Map<String, dynamic>);
    final result = validateLevel(level);

    if (!result.ok) {
      stderr.writeln(result);
      failed++;
      continue;
    }

    final plan = result.plan!;
    stdout.writeln('Level ${level.id.toString().padLeft(2)}  '
        '${level.length.round().toString().padLeft(4)}u  '
        '${level.runSpeed.round()}/s  '
        'hop ${level.hopPeriod.toStringAsFixed(2)}  '
        '${level.bolted.length}B ${level.hoppers.length}H '
        '${level.blades.length}K ${level.stones.length}S  '
        '${plan.actions.toString().padLeft(2)} inputs');
    if (verbose) stdout.writeln('    $plan');
  }

  stopwatch.stop();
  stdout.writeln('\n${raw.length} levels checked in ${stopwatch.elapsedMilliseconds}ms');
  stdout.writeln('hop air time ${kHopAirTime.toStringAsFixed(3)}s, '
      'hop peak ${kHopPeak.toStringAsFixed(1)}u, '
      'jump peak ${kJumpPeak.toStringAsFixed(1)}u');

  if (failed > 0) {
    stderr.writeln('$failed level(s) failed validation.');
    exit(1);
  }
}

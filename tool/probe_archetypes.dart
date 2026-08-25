// Authoring tool. Solves a sample of every archetype before the long run.
//
//   dart run tool/probe_archetypes.dart
//
// Run this after touching [kArchetypes] and before generating the pack.
// tool/generate_levels.dart writes nothing if a single level of ten thousand
// fails, so a badly weighted archetype costs a four hour run to discover. A
// --sample run does not help: it spreads by id, which says nothing about
// whether every archetype was covered. This picks levels *by* archetype, so
// each one is actually exercised, and finishes in a few minutes.
//
// Exits non zero if any level fails.

import 'dart:io';
import 'dart:isolate';

import 'package:pitchpole/game/logic/level_generator.dart';
import 'package:pitchpole/game/logic/level_simulator.dart';

const int perArchetype = 10;

({int id, bool ok, String why}) probe(int id) {
  final level = generateLevel(id);
  final result = validateLevel(level);
  return (
    id: id,
    ok: result.ok,
    why: result.ok ? '' : result.problems.join('; '),
  );
}

Future<void> main() async {
  // Walked backwards from the end of the pack on purpose: difficulty rises all
  // the way to [kTotalLevels], so the last levels of each archetype are the
  // hardest ones it will ever produce and the only ones in real danger of
  // being unsolvable. Sampling from 301 upwards — which is what this did when
  // difficulty went flat after the ramp — would now test the easiest plateau
  // levels and pass while the end of the pack was impossible.
  final byName = <String, List<int>>{};
  for (var id = kTotalLevels; id > kRampEndLevel; id--) {
    final name = archetypeFor(id).name;
    final bucket = byName.putIfAbsent(name, () => []);
    if (bucket.length < perArchetype) bucket.add(id);
    if (byName.length == kArchetypes.length &&
        byName.values.every((b) => b.length == perArchetype)) {
      break;
    }
  }

  stdout.writeln('${kArchetypes.length} archetypes, '
      'solving $perArchetype levels of each');

  final concurrency = (Platform.numberOfProcessors - 2).clamp(1, 16);
  var failed = 0;
  final started = DateTime.now();

  for (final entry in byName.entries) {
    final ids = entry.value;
    final results = <({int id, bool ok, String why})>[];
    // Simple batched fan out; the whole probe is only a couple of hundred
    // levels, so there is nothing to gain from a proper pool here.
    for (var i = 0; i < ids.length; i += concurrency) {
      final slice = ids.skip(i).take(concurrency);
      results.addAll(
        await Future.wait([for (final id in slice) Isolate.run(() => probe(id))]),
      );
    }

    final bad = results.where((r) => !r.ok).toList();
    failed += bad.length;
    stdout.writeln('  ${entry.key.padRight(12)} '
        '${results.length - bad.length}/${results.length} ok'
        '${bad.isEmpty ? '' : '   <-- FAILURES'}');
    for (final b in bad.take(3)) {
      stdout.writeln('      level ${b.id}: ${b.why}');
    }
  }

  final seconds = DateTime.now().difference(started).inSeconds;
  stdout.writeln('$failed failure(s) in ${seconds}s');
  if (failed > 0) exit(1);
}

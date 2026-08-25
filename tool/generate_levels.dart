// Authoring tool. Builds the level pack and checks every level with the same
// validator the tests use.
//
//   dart run tool/generate_levels.dart --sample 40   # smoke test, no write
//   dart run tool/generate_levels.dart               # build and write the pack
//   dart run tool/generate_levels.dart --coins-only  # relay coins, keep levels
//
// Levels 1 to 5 are hand placed and are read out of assets/levels/taught.json
// untouched. Everything from 6 up is generated from its own id, so the output
// is reproducible: running this twice gives byte identical JSON.
//
// The pack is written as shards rather than as one file, because ten thousand
// levels in a single array peaks at around 480 MB to decode and Android will
// not give an app that much on a cheap phone. See level_pack.dart.
//
// Validating a level means solving it, which costs about a second, so the
// checking is spread across isolates and a full run takes hours. Exits non zero
// if a single level fails, and writes no pack.
//
// **The work is done in chunks of [_chunkSize] and every finished chunk is
// written to `.level_cache/` before the next one starts.** A run that is
// interrupted — a reboot, a kill, a laptop lid — therefore loses at most one
// chunk instead of everything, and starting again picks up where it stopped.
// At four hours a run, that is the difference between an interruption costing
// two minutes and costing the afternoon.
//
// The cache is keyed on a signature of everything that decides what
// `generateLevel` produces. Change an archetype or a ramp constant and the
// signature moves, the cache is dropped, and every level is built again — so
// a stale chunk can never survive into a pack. Changing [kTotalLevels] alone
// does *not* invalidate it, because a level's content depends on its own id
// and not on how many levels come after it.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:pitchpole/game/logic/level_generator.dart';
import 'package:pitchpole/game/logic/level_model.dart';
import 'package:pitchpole/game/logic/level_pack.dart';
import 'package:pitchpole/game/logic/level_simulator.dart';

/// How many levels are solved before anything is written down.
///
/// A hundred is about two and a half minutes of work at six isolates, which is
/// a small enough amount to lose to an interruption and a large enough batch
/// that the isolate pool is never starved waiting for a write.
const int _chunkSize = 100;

/// Where finished chunks live between runs. Gitignored: it is scratch work,
/// and the pack it produces is the thing worth committing.
const String _cacheDir = '.level_cache';

/// Bump when something changes inside the generator that the signature below
/// cannot see — a tweak to `_slots`, a new phase rule, anything that changes
/// what a level contains without changing a constant this file reads.
const int _generatorVersion = 3;

/// Everything that decides what `generateLevel(id)` produces.
///
/// [kTotalLevels] is part of this now, and that is a correctness fix rather
/// than a tidy-up. It used to be left out on the grounds that a level is a
/// pure function of its own id, so lengthening the pack left every solved
/// level untouched and a cache built for 1,500 was still good for 10,000.
///
/// That stopped being true when difficulty started climbing all the way to the
/// end of the pack: [lateRampAt] divides by `kTotalLevels - kRampEndLevel`, so
/// every level past 300 now depends on how long the pack is. Leaving it out
/// would let a cache built for one length be reused for another and quietly
/// ship levels that no longer match the code that claims to describe them.
String _signature() {
  final buffer = StringBuffer()
    ..write('v$_generatorVersion;')
    ..write('first=$kFirstGeneratedLevel;')
    ..write('ramp=$kRampEndLevel;')
    ..write('total=$kTotalLevels;')
    ..write('bat=$kBatIntroLevel;spider=$kSpiderIntroLevel;');
  for (final archetype in kArchetypes) {
    buffer.write('${archetype.name}[');
    // Sorted, so a reordered map literal is not mistaken for a real change.
    final kinds = archetype.weights.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    for (final kind in kinds) {
      buffer.write('${kind.name}:${archetype.weights[kind]},');
    }
    buffer.write('];');
  }
  return buffer.toString();
}

/// What one worker gives back.
class _Checked {
  const _Checked(this.id, this.problems, this.actions, this.coins, this.json);

  final int id;
  final List<String> problems;
  final int actions;
  final int coins;

  /// The finished level, coins included. Carried back from the worker so the
  /// writer does not have to solve ten thousand levels a second time.
  final Map<String, dynamic>? json;

  bool get ok => problems.isEmpty;
}

/// The frontier the solve is attempted at first.
///
/// Measured across the plateau, the search rarely needs anything like the
/// four thousand states the solver defaults to. Every level tried still solved
/// at two hundred, and the cost falls with the cap: 7.9s at 600, 3.6s at 300,
/// 2.5s at 200. Two hundred and fifty keeps a little margin and is about three
/// times cheaper than the six hundred this started at.
///
/// This is safe rather than a trade-off, because of [_fullFrontier] below. A
/// smaller frontier is a *weaker* search, never a more permissive one — it can
/// miss a route, but it cannot invent one — so a level is only ever reported
/// broken after the full search has also failed on it.
const int _fastFrontier = 250;
const int _fullFrontier = 4000;

/// Generates one level, validates it, and lays coins along the route the
/// solver proved. Runs in its own isolate, so it takes and returns plain data.
_Checked _check(int id) {
  final level = generateLevel(id);

  var result = validateLevel(level, frontierCap: _fastFrontier);
  if (!result.ok) {
    // Might be a real problem, might just be the narrow search giving up.
    // Only the full one gets to condemn a level.
    result = validateLevel(level, frontierCap: _fullFrontier);
  }
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

/// The chunk cache: finished work, kept between runs.
///
/// One file per chunk of [_chunkSize] levels, named for the id it starts at.
/// A chunk is only written once every level in it has been solved, so a file
/// being present means that whole range is done and can be trusted.
class _Cache {
  _Cache(this.dir);

  final Directory dir;

  File get _signatureFile => File('${dir.path}/signature.txt');

  File chunkFile(int startId) =>
      File('${dir.path}/chunk_${startId.toString().padLeft(5, '0')}.json');

  /// Opens the cache, throwing away anything built by a different generator.
  ///
  /// This is the guard that makes the cache safe to keep: without it, editing
  /// an archetype and rerunning would happily assemble a pack out of levels
  /// built by the old rules and levels built by the new ones.
  int open() {
    dir.createSync(recursive: true);
    final want = _signature();
    final have =
        _signatureFile.existsSync() ? _signatureFile.readAsStringSync() : null;

    if (have == want) return _countCached();

    if (have != null) {
      stdout.writeln('the generator changed since the cache was built, '
          'starting over');
    }
    for (final stale in dir.listSync().whereType<File>()) {
      stale.deleteSync();
    }
    _signatureFile.writeAsStringSync(want);
    return 0;
  }

  int _countCached() {
    var levels = 0;
    for (final file in dir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      levels += (jsonDecode(file.readAsStringSync()) as List<dynamic>).length;
    }
    return levels;
  }

  /// The chunk starting at [startId], or null if it is absent, corrupt, or
  /// does not hold exactly the ids [expect] asks for.
  ///
  /// That last check is not paranoia. The final chunk of a pack is short — a
  /// run of 250 levels ends with 206..250 — so raising [kTotalLevels] turns a
  /// once complete chunk into a partial one that now needs 206..305. Without
  /// this the cache would hand back the short version and the pack would come
  /// out with a hole in it.
  List<Map<String, dynamic>>? read(int startId, {List<int>? expect}) {
    final file = chunkFile(startId);
    if (!file.existsSync()) return null;

    List<Map<String, dynamic>> levels;
    try {
      levels = (jsonDecode(file.readAsStringSync()) as List<dynamic>)
          .cast<Map<String, dynamic>>();
    } on FormatException {
      // A chunk half written when the power went is worth less than nothing.
      file.deleteSync();
      return null;
    }

    if (expect != null) {
      final ids = [for (final level in levels) level['id'] as int];
      if (ids.length != expect.length ||
          ids.first != expect.first ||
          ids.last != expect.last) {
        file.deleteSync();
        return null;
      }
    }
    return levels;
  }

  void write(int startId, List<Map<String, dynamic>> levels) {
    // Written beside the real name and then moved, so a chunk file never
    // exists in a half written state for the next run to trust.
    final temp = File('${chunkFile(startId).path}.part')
      ..writeAsStringSync(const JsonEncoder().convert(levels));
    temp.renameSync(chunkFile(startId).path);
  }

  void clear() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

/// The id each chunk starts at, covering [kFirstGeneratedLevel] to
/// [kTotalLevels].
List<int> _chunkStarts() => [
      for (var id = kFirstGeneratedLevel; id <= kTotalLevels; id += _chunkSize)
        id,
    ];

/// Reads the whole pack back off disk, shard by shard.
List<LevelModel> _readPack() {
  final levels = <LevelModel>[];
  for (final start in shardStarts(kTotalLevels)) {
    final file = File(shardPathAt(start));
    if (!file.existsSync()) break;
    levels.addAll(
      (jsonDecode(file.readAsStringSync()) as List<dynamic>)
          .map((e) => LevelModel.fromJson(e as Map<String, dynamic>)),
    );
  }
  return levels;
}

/// Recomputes coins for the pack already on disk, leaving every level's
/// obstacles exactly as they are.
///
/// Coins are worked out without the solver, and they cannot change whether a
/// level is completable, so relaying them does not need the whole pack to be
/// validated again. That turns an hours long job into a few seconds.
Future<void> _relayCoins() async {
  final pack = _readPack();
  if (pack.isEmpty) {
    stdout.writeln('no shards on disk, nothing to relay');
    exit(1);
  }

  final relaid = [for (final level in pack) level.withCoins(coinsFor(level))];
  await _writeShards([for (final l in relaid) l.toJson()]);

  final coins = relaid.fold(0, (sum, l) => sum + l.coins.length);
  stdout.writeln('relaid coins on ${relaid.length} levels: $coins coins');
}

Future<void> main(List<String> args) async {
  if (args.contains('--coins-only')) return _relayCoins();

  final sampleIndex = args.indexOf('--sample');
  final sample = sampleIndex >= 0 && sampleIndex + 1 < args.length
      ? int.parse(args[sampleIndex + 1])
      : 0;
  final verbose = args.contains('--verbose');

  // Every core. This is a job measured in hours, and the two cores that used
  // to be held back for the sake of a responsive desktop were costing about a
  // third of the throughput. Pass --gentle to get them back.
  final spare = args.contains('--gentle') ? 2 : 0;
  final concurrency = (Platform.numberOfProcessors - spare).clamp(1, 16);

  if (sample > 0) return _runSample(_spread(sample), concurrency, verbose);

  final cache = _Cache(Directory(_cacheDir));
  if (args.contains('--fresh')) {
    cache.clear();
    stdout.writeln('cache cleared on request');
  }

  final alreadyDone = cache.open();
  final total = kTotalLevels - kFirstGeneratedLevel + 1;
  final starts = _chunkStarts();

  stdout.writeln('$total generated levels in ${starts.length} chunks of '
      '$_chunkSize, across $concurrency isolates');
  if (alreadyDone > 0) {
    stdout.writeln('$alreadyDone already done in a previous run, resuming');
  }

  final started = DateTime.now();
  var done = alreadyDone;

  for (var chunk = 0; chunk < starts.length; chunk++) {
    final start = starts[chunk];
    final ids = [
      for (var id = start; id < start + _chunkSize && id <= kTotalLevels; id++)
        id,
    ];
    if (cache.read(start, expect: ids) != null) continue;


    final checked = await _pool<_Checked>(
      ids,
      (id) => Isolate.run(() => _check(id)),
      concurrency: concurrency,
    );

    final failed = checked.where((c) => !c.ok).toList();
    if (failed.isNotEmpty) {
      stdout.writeln();
      for (final failure in failed.take(25)) {
        stdout.writeln('Level ${failure.id}: ${failure.problems.join('; ')}');
      }
      if (failed.length > 25) {
        stdout.writeln('... and ${failed.length - 25} more');
      }
      stdout.writeln('${failed.length} level(s) failed in the chunk starting '
          'at $start. Nothing written for it, and no pack assembled — but '
          'every chunk finished before this one is kept, so fixing the '
          'generator and running again resumes from here.');
      exit(1);
    }

    // Only now, with the whole chunk proven, does it become durable.
    cache.write(start, [for (final c in checked) c.json!]);
    done += ids.length;

    final elapsed = DateTime.now().difference(started);
    final fresh = done - alreadyDone;
    final rate = fresh / (elapsed.inMilliseconds / 1000);
    final left = rate > 0
        ? Duration(seconds: ((total - done) / rate).round())
        : Duration.zero;
    stdout.writeln('  chunk ${chunk + 1}/${starts.length}  '
        'levels $start..${ids.last}  '
        '$done/$total done  '
        '${elapsed.inMinutes}m elapsed  about ${left.inMinutes}m left');

    if (verbose) _describe(checked.take(4));
  }

  final minutes =
      DateTime.now().difference(started).inMilliseconds / 1000 / 60;
  stdout.writeln('all $total generated levels ok '
      'in ${minutes.toStringAsFixed(1)} min');

  await _write(starts, cache);
}

/// A spread across the whole pack, solved but never written. The smoke test.
Future<void> _runSample(
  List<int> ids,
  int concurrency,
  bool verbose,
) async {
  stdout.writeln('sampling ${ids.length} levels across $concurrency isolates');
  final started = DateTime.now();

  final checked = await _pool<_Checked>(
    ids,
    (id) => Isolate.run(() => _check(id)),
    concurrency: concurrency,
    onProgress: (done, total) {
      if (done % 10 == 0 || done == total) {
        stdout.write('\r  $done / $total   ');
      }
    },
  );
  stdout.writeln();

  final failed = checked.where((c) => !c.ok).toList();
  for (final failure in failed.take(25)) {
    stdout.writeln('Level ${failure.id}: ${failure.problems.join('; ')}');
  }
  if (verbose) _describe(checked.take(40));

  final seconds = DateTime.now().difference(started).inMilliseconds / 1000;
  stdout.writeln('${checked.length - failed.length} of ${checked.length} ok '
      'in ${seconds.toStringAsFixed(1)}s');
  stdout.writeln('sample run, nothing written');
  if (failed.isNotEmpty) exit(1);
}

void _describe(Iterable<_Checked> checked) {
  for (final c in checked) {
    final level = generateLevel(c.id);
    stdout.writeln('    Level ${c.id.toString().padLeft(5)}  '
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

/// A spread of ids across the whole pack rather than the first N, so a sample
/// exercises the ramp, the speed steps and every archetype.
List<int> _spread(int count) {
  final span = kTotalLevels - kFirstGeneratedLevel;
  return [
    for (var i = 0; i < count; i++)
      kFirstGeneratedLevel + (span * i / (count - 1)).round(),
  ];
}

/// Assembles the pack out of the hand placed levels and the chunk cache.
Future<void> _write(List<int> starts, _Cache cache) async {
  final taught =
      (jsonDecode(await File(kTaughtPath).readAsString()) as List<dynamic>)
          .map((e) => LevelModel.fromJson(e as Map<String, dynamic>))
          .toList();

  stdout.writeln('keeping ${taught.length} hand placed levels');

  // The taught levels get coins the same way the generated ones do, and are
  // solved as well so a hand placed level can never quietly stop working.
  final pack = <Map<String, dynamic>>[];
  for (final level in taught) {
    if (solveLevel(level) == null) {
      stdout.writeln('level ${level.id} could not be solved, nothing written');
      exit(1);
    }
    final withCoins = level.withCoins(coinsFor(level));
    stdout.writeln('  level ${level.id}: ${withCoins.coins.length} coins');
    pack.add(withCoins.toJson());
  }

  for (final start in starts) {
    final ids = [
      for (var id = start; id < start + _chunkSize && id <= kTotalLevels; id++)
        id,
    ];
    final chunk = cache.read(start, expect: ids);
    if (chunk == null) {
      stdout.writeln('the chunk starting at $start is missing from the cache, '
          'nothing written');
      exit(1);
    }
    pack.addAll(chunk);
  }

  await _writeShards(pack);
}

/// Writes the pack out as shards plus the index, and deletes any shard left
/// over from a longer pack, so the directory can never hold two generations of
/// levels at once.
Future<void> _writeShards(List<Map<String, dynamic>> pack) async {
  if (pack.length != kTotalLevels) {
    stdout.writeln('refusing to write ${pack.length} levels, '
        'expected $kTotalLevels');
    exit(1);
  }

  // Ids have to be contiguous and in order: the app works out which shard a
  // level is in by arithmetic on its id rather than by searching for it, so a
  // gap here would silently hand the player the wrong level.
  for (var i = 0; i < pack.length; i++) {
    if (pack[i]['id'] != i + 1) {
      final wrong = pack[i]['id'];
      stdout.writeln('level at position $i has id $wrong, expected ${i + 1}');
      exit(1);
    }
  }

  const encoder = JsonEncoder();
  var bytes = 0;
  for (final start in shardStarts(pack.length)) {
    final slice = pack.skip(start - 1).take(kShardSize).toList();
    final file = File(shardPathAt(start));
    await file.writeAsString('${encoder.convert(slice)}\n');
    bytes += await file.length();
  }

  final index = {'count': pack.length, 'shardSize': kShardSize};
  await File(kIndexPath).writeAsString('${encoder.convert(index)}\n');

  // A shorter pack than last time leaves orphans behind. The app would never
  // read them, but the APK would still carry them.
  //
  // The scan starts at the shard *after* the last one written, not at
  // `pack.length + 1`: a pack that does not fill its final shard sits inside
  // it, so rounding that id down to a shard start lands back on a live file
  // and deletes the level pack that was just written.
  final firstOrphan = shardCount(pack.length) * kShardSize + 1;
  for (var start = firstOrphan;; start += kShardSize) {
    final stale = File(shardPathAt(start));
    if (!stale.existsSync()) break;
    stale.deleteSync();
    stdout.writeln('removed stale ${stale.path}');
  }

  final coins = pack.fold<int>(
    0,
    (sum, l) => sum + ((l['coins'] as List<dynamic>?)?.length ?? 0),
  );
  final shards = shardCount(pack.length);
  stdout.writeln('wrote ${pack.length} levels as $shards shards '
      '(${(bytes / 1024 / 1024).toStringAsFixed(2)} MB, '
      '${(bytes / shards / 1024).round()} KB each), $coins coins');
}

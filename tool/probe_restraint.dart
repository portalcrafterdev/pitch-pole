/// Asks whether the two restraint achievements can actually be earned.
///
/// `Featherfoot` wants a level finished without ever jumping and `Held Ground`
/// wants one finished on at most three flips. Both were written from taste
/// rather than from evidence, and an achievement nobody can earn is worse than
/// no achievement at all: it sits at 0% forever and there is nothing in the
/// game that says why.
///
/// So this runs the solver over the front of the pack with those restraints
/// applied and reports the first level that survives each. Authoring time
/// only, like every other probe here.
///
///   dart run tool/probe_restraint.dart [--to 60]
library;

import 'dart:convert';
import 'dart:io';

import 'package:pitchpole/game/logic/level_model.dart';
import 'package:pitchpole/game/logic/level_pack.dart';
import 'package:pitchpole/game/logic/level_simulator.dart';

int _flag(List<String> args, String name, int fallback) {
  final i = args.indexOf('--$name');
  if (i < 0 || i + 1 >= args.length) return fallback;
  return int.tryParse(args[i + 1]) ?? fallback;
}

List<LevelModel> _load(int upTo) {
  final levels = <LevelModel>[];
  for (final start in shardStarts(kTotalLevels)) {
    if (start > upTo) break;
    final file = File(shardPathAt(start));
    if (!file.existsSync()) break;
    levels.addAll(
      (jsonDecode(file.readAsStringSync()) as List<dynamic>)
          .map((e) => LevelModel.fromJson(e as Map<String, dynamic>)),
    );
  }
  return levels.where((l) => l.id <= upTo).toList();
}

void main(List<String> args) {
  final upTo = _flag(args, 'to', 60);
  final levels = _load(upTo);
  if (levels.isEmpty) {
    stderr.writeln('no pack in $kLevelsDir; run tool/generate_levels.dart');
    exit(1);
  }

  int? noJump;
  int? threeFlips;
  final jumpFree = <int>[];
  final flipLean = <int>[];

  for (final level in levels) {
    if (solveLevel(level, allowJump: false) != null) {
      noJump ??= level.id;
      jumpFree.add(level.id);
    }
    if (solveLevel(level, maxFlips: 3) != null) {
      threeFlips ??= level.id;
      flipLean.add(level.id);
    }
  }

  stdout.writeln('checked levels 1..$upTo');
  stdout.writeln('Featherfoot  (no jump at all): '
      '${noJump == null ? 'NOT EARNABLE in this range' : 'first at level '
          '$noJump, ${jumpFree.length} of $upTo qualify'}');
  stdout.writeln('Held Ground  (3 flips or fewer): '
      '${threeFlips == null ? 'NOT EARNABLE in this range' : 'first at level '
          '$threeFlips, ${flipLean.length} of $upTo qualify'}');
  if (jumpFree.isNotEmpty) {
    stdout.writeln('  jump free : ${jumpFree.take(12).join(', ')}');
  }
  if (flipLean.isNotEmpty) {
    stdout.writeln('  flip lean : ${flipLean.take(12).join(', ')}');
  }
}

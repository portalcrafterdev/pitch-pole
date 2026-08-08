import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

import '../game/logic/level_model.dart';

/// Parses the pack. Top level so it can be handed to another isolate.
///
/// At fifteen hundred levels this is a few megabytes of JSON, which is long
/// enough to drop frames if it runs on the main isolate while the home screen
/// is coming up.
List<LevelModel> _parse(String raw) {
  final decoded = jsonDecode(raw) as List<dynamic>;
  return [
    for (final e in decoded) LevelModel.fromJson(e as Map<String, dynamic>),
  ];
}

/// Loads the level pack. Levels are pure data; nothing here decides how a
/// level plays.
class LevelRepository {
  static const String assetPath = 'assets/levels/levels.json';

  List<LevelModel>? _cache;
  Map<int, LevelModel>? _byId;

  /// In flight load, so two screens asking at once share one parse instead of
  /// racing and doing the work twice.
  Future<List<LevelModel>>? _loading;

  Future<List<LevelModel>> loadAll() async {
    final cached = _cache;
    if (cached != null) return cached;
    return _loading ??= _load();
  }

  Future<List<LevelModel>> _load() async {
    final raw = await rootBundle.loadString(assetPath);
    final levels = await compute(_parse, raw);
    _cache = levels;
    _byId = {for (final level in levels) level.id: level};
    _loading = null;
    return levels;
  }

  Future<LevelModel?> byId(int id) async {
    await loadAll();
    return _byId?[id];
  }
}

final LevelRepository levelRepository = LevelRepository();

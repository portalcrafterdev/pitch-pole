import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../game/logic/level_model.dart';

/// Loads the level pack. Levels are pure data; nothing here decides how a
/// level plays.
class LevelRepository {
  static const String assetPath = 'assets/levels/levels.json';

  List<LevelModel>? _cache;

  Future<List<LevelModel>> loadAll() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = jsonDecode(await rootBundle.loadString(assetPath));
    final levels = (raw as List<dynamic>)
        .map((e) => LevelModel.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return _cache = levels;
  }

  Future<LevelModel?> byId(int id) async {
    final levels = await loadAll();
    for (final level in levels) {
      if (level.id == id) return level;
    }
    return null;
  }
}

final LevelRepository levelRepository = LevelRepository();

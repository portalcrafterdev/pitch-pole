import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

import '../game/logic/level_model.dart';
import '../game/logic/level_pack.dart';

/// Parses one shard. Top level so it can be handed to another isolate.
List<LevelModel> _parse(String raw) {
  final decoded = jsonDecode(raw) as List<dynamic>;
  return [
    for (final e in decoded) LevelModel.fromJson(e as Map<String, dynamic>),
  ];
}

/// Loads the level pack. Levels are pure data; nothing here decides how a
/// level plays.
///
/// The pack is ten thousand levels and 29 MB of JSON, and decoding all of it
/// at once peaks around 480 MB — more than Android hands an app on a 2 GB
/// phone, so the whole-pack version is killed at launch on cheap devices and
/// freezes for seconds on the rest. So nothing here ever reads the whole pack:
///
///  * [count] reads a 29 byte index and no levels at all. The menus and the
///    level select grid need the number of levels and the player's own saved
///    stars, and neither of those is in the pack.
///  * [byId] loads only the shard the level is in, on another isolate, and
///    keeps the last couple of shards so walking through the pack in order
///    does not reload one per level.
class LevelRepository {
  /// How many shards to hold on to.
  ///
  /// Two, because the common move is finishing a level and starting the next
  /// one, which crosses a shard boundary once every [kShardSize] levels. One
  /// would drop the shard being played out of the cache at that moment and
  /// read it straight back in.
  static const int _cacheSize = 2;

  int? _count;
  Future<int>? _counting;

  /// Shard start id to the levels in it, most recently used last.
  final Map<int, List<LevelModel>> _shards = {};
  final Map<int, Future<List<LevelModel>>> _loadingShards = {};

  /// How many levels ship. Cheap: this reads the index, never a level.
  Future<int> count() async {
    final known = _count;
    if (known != null) return known;
    return _counting ??= _readCount();
  }

  Future<int> _readCount() async {
    final raw = await rootBundle.loadString(kIndexPath);
    final index = jsonDecode(raw) as Map<String, dynamic>;
    final count = index['count'] as int;
    _count = count;
    _counting = null;
    return count;
  }

  Future<LevelModel?> byId(int id) async {
    if (id < 1) return null;
    final shard = await _shard(shardStartFor(id));
    final at = id - shardStartFor(id);
    return at < shard.length ? shard[at] : null;
  }

  Future<List<LevelModel>> _shard(int start) async {
    final cached = _shards[start];
    if (cached != null) {
      // Touch it, so the least recently used shard is the one evicted.
      _shards.remove(start);
      _shards[start] = cached;
      return cached;
    }
    return _loadingShards[start] ??= _loadShard(start);
  }

  Future<List<LevelModel>> _loadShard(int start) async {
    try {
      final raw = await rootBundle.loadString(shardPathAt(start));
      final levels = await compute(_parse, raw);
      _shards[start] = levels;
      while (_shards.length > _cacheSize) {
        _shards.remove(_shards.keys.first);
      }
      return levels;
    } finally {
      _loadingShards.remove(start);
    }
  }

  /// Every level in the pack, in order.
  ///
  /// Reads and decodes all ten thousand, so it must never be called from the
  /// app: it is here for the tests and the authoring tools, which check the
  /// whole pack and can afford the memory. The game reaches levels through
  /// [byId] and counts them with [count].
  Future<List<LevelModel>> loadAll() async {
    final total = await count();
    final levels = <LevelModel>[];
    for (final start in shardStarts(total)) {
      levels.addAll(_parse(await rootBundle.loadString(shardPathAt(start))));
    }
    return levels;
  }
}

final LevelRepository levelRepository = LevelRepository();

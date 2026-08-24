import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/game/logic/level_pack.dart';

/// The pack is found by arithmetic rather than by searching: the app works out
/// which file a level is in from its id alone, and reads only that file. That
/// is what keeps ten thousand levels off the heap, and it is also what makes an
/// off by one here silent — the player gets a level, just not the one on the
/// tile they pressed. So the arithmetic is tested on its own, without assets.
void main() {
  test('a level id lands in the shard named after its own range', () {
    expect(shardStartFor(1), 1);
    expect(shardStartFor(kShardSize), 1, reason: 'the last id in shard one');
    expect(shardStartFor(kShardSize + 1), kShardSize + 1,
        reason: 'the first id in shard two');
    expect(shardStartFor(kShardSize * 2), kShardSize + 1);
    expect(shardStartFor(kTotalLevels), shardStarts(kTotalLevels).last);
  });

  test('every level in the pack is in exactly one shard', () {
    final starts = shardStarts(kTotalLevels).toSet();
    for (var id = 1; id <= kTotalLevels; id++) {
      final start = shardStartFor(id);
      expect(starts, contains(start),
          reason: 'level $id points at shard $start, which is not written');
      expect(id, greaterThanOrEqualTo(start));
      expect(id, lessThan(start + kShardSize));
    }
  });

  test('the shards cover the pack with nothing left over', () {
    expect(shardCount(kTotalLevels), kShardCount);
    expect(shardStarts(kTotalLevels).length, kShardCount);
    expect(shardStarts(kTotalLevels).first, 1);
    // The last shard has to reach the last level and stop within one shard of
    // it, or the pack is either short or padded with a file of nothing.
    final last = shardStarts(kTotalLevels).last;
    expect(last, lessThanOrEqualTo(kTotalLevels));
    expect(last + kShardSize, greaterThan(kTotalLevels));
  });

  test('a partly filled last shard does not invent an extra one', () {
    // kShardSize + 1 levels is the case that used to delete the pack it had
    // just written: the orphan scan rounded `count + 1` back down into the
    // final live shard. Two shards, not three, and the second is nearly empty.
    expect(shardCount(kShardSize + 1), 2);
    expect(shardCount(kShardSize), 1);
    expect(shardCount(1), 1);
    expect(shardStarts(kShardSize + 1), [1, kShardSize + 1]);
  });

  test('a shard is named for its first level, zero padded', () {
    expect(shardPathAt(1), '$kLevelsDir/shard_00001.json');
    expect(shardPathFor(1), shardPathAt(1));
    expect(shardPathFor(kShardSize + 1), shardPathAt(kShardSize + 1));
    // Padded so the files sort in the order they are played, which is the
    // order anyone reading the directory expects them in.
    expect(shardPathAt(10000), '$kLevelsDir/shard_10000.json');
  });
}

/// Where the level pack lives on disk, and how it is cut up.
///
/// This file must never import Flame, Flutter or dart:ui: the authoring tool
/// writes the pack with it and the app reads the pack with it, and they have to
/// agree exactly or the game loads the wrong level.
///
/// The pack is split into shards rather than kept as one file, and that is a
/// memory decision rather than a tidiness one. Ten thousand levels is 29 MB of
/// JSON, and decoding all of it at once peaks at around 480 MB — more than
/// Android will give an app on a 2 GB phone, so the single file version is
/// killed at launch on cheap devices and freezes for seconds on the rest.
/// One shard is a fortieth of that.
///
/// Levels are still fixed, repeatable data, exactly as rule 5 requires. This
/// changes how the bytes are stored, not where they come from: level 8,472 is
/// the same level for everybody, forever.
library;

/// How many levels ship.
///
/// This lives here rather than with the generator because it is a fact about
/// the pack on disk, not about the thing that wrote it. Nothing under `lib/`
/// may reach into the generator to ask: it is authoring code, it runs for
/// hours, and it has no business being linked into the game.
const int kTotalLevels = 10000;

/// How many levels go in one file.
///
/// 250 keeps a shard near 750 KB, which decodes in well under a frame's budget
/// on a phone and peaks around 12 MB. Bigger shards mean fewer files and more
/// memory; smaller ones mean more files and more asset lookups. Changing this
/// changes every shard's name, so the pack has to be rewritten with it.
const int kShardSize = 250;

/// Directory holding the pack. Declared in pubspec as a directory, so a shard
/// added by the tool is bundled without touching the manifest.
const String kLevelsDir = 'assets/levels';

/// The hand placed levels, kept apart because they are edited by hand and the
/// rest are not. The tool reads this and never writes it.
const String kTaughtPath = '$kLevelsDir/taught.json';

/// Written by the tool so the app knows how many levels there are without
/// reading a single one of them. The level select grid needs the count and
/// nothing else, and paying 29 MB to learn one integer is what the shards are
/// here to avoid.
const String kIndexPath = '$kLevelsDir/index.json';

/// How many shards the whole pack takes.
int get kShardCount => shardCount(kTotalLevels);

int shardCount(int total) => (total + kShardSize - 1) ~/ kShardSize;

/// The id the shard holding [id] starts at. Shards are named after it, so the
/// name can be worked out from a level id without a lookup table.
int shardStartFor(int id) => ((id - 1) ~/ kShardSize) * kShardSize + 1;

/// Path of the shard holding [id].
String shardPathFor(int id) => shardPathAt(shardStar
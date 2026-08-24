// Authoring tool. Writes the achievement CSVs for the Play Console import.
//
//   dart run tool/make_achievement_csvs.dart
//
// The format is not guessed: it is
// https://developer.android.com/games/pgs/integrate-achievements#zip-file
//
//   AchievementsMetadata.csv
//     Name, Description, Incremental value, Steps Needed, Initial State,
//     Points, List Order
//
//   AchievementsIconsMappings.csv
//     Name, icon filename
//
// Both are written **without a header row** — the importer reads row one as
// data, so a header becomes a bogus achievement called "Name".
//
// Three rules from that page are easy to break by hand and are asserted here
// instead:
//
//   * Name and Description must not contain commas. The importer splits on
//     them and does not honour quoting, so one comma shifts every later column
//     along by one and the row fails as the wrong shape.
//   * Points must be a multiple of 5 between 5 and 200, and Play allows 1000
//     across the whole game.
//   * Steps Needed caps at 10000, so anything counting higher than that has to
//     be a plain unlock rather than an incremental one.
//
// AchievementsLocalizations.csv is deliberately **not** written. It exists to
// add languages beyond the default, and the page is explicit that the default
// locale cannot be listed in it. The game ships in English only, so the file
// would hold nothing but rows Play rejects.

import 'dart:io';

const String _outDir = 'store/achievements';

/// Play's own limits, from the page above.
const int _maxSteps = 10000;
const int _maxPoints = 1000;
const int _maxName = 100;
const int _maxDescription = 500;

class Achievement {
  const Achievement({
    required this.icon,
    required this.name,
    required this.description,
    required this.points,
    this.steps,
    this.hidden = false,
  });

  /// The base of the icon filename. Not sent to Play as an identifier — the
  /// Name is what the mapping file links on — but it keeps the icon tool and
  /// this one talking about the same achievement.
  final String icon;

  /// What Play calls the achievement, and the key both CSVs join on.
  final String name;
  final String description;
  final int points;

  /// Non null makes it incremental, and is the number of steps to fill.
  final int? steps;
  final bool hidden;

  bool get incremental => steps != null;

  String get metadataRow => [
        name,
        description,
        incremental ? 'True' : 'False',
        steps?.toString() ?? '',
        hidden ? 'Hidden' : 'Revealed',
        points.toString(),
      ].join(',');
}

/// The set, in list order. Points total exactly 1000.
const List<Achievement> achievements = [
  // Progression.
  Achievement(
    icon: 'first_steps',
    name: 'First Steps',
    description: 'Clear level 1.',
    points: 5,
  ),
  Achievement(
    icon: 'taught',
    name: 'Taught',
    description: 'Clear all five teaching levels.',
    points: 5,
  ),
  Achievement(
    icon: 'two_dozen',
    name: 'Two Dozen',
    description: 'Clear 25 levels.',
    points: 10,
    steps: 25,
  ),
  Achievement(
    icon: 'century',
    name: 'Century',
    description: 'Clear 100 levels.',
    points: 15,
    steps: 100,
  ),
  Achievement(
    icon: 'past_the_ramp',
    name: 'Past the Ramp',
    // No comma: the importer would read it as a column break.
    description: 'Clear level 300 where the game stops getting harder and '
        'starts changing shape.',
    points: 25,
  ),
  Achievement(
    icon: 'thousand',
    name: 'Thousand',
    description: 'Clear 1000 levels.',
    points: 35,
    steps: 1000,
  ),
  Achievement(
    icon: 'quarter',
    name: 'Quarter',
    description: 'Clear 2500 levels.',
    points: 45,
    steps: 2500,
  ),
  Achievement(
    icon: 'halfway',
    name: 'Halfway',
    description: 'Clear 5000 levels.',
    points: 60,
    steps: 5000,
  ),
  Achievement(
    icon: 'pitchpole',
    name: 'Pitchpole',
    description: 'Clear all 10000 levels.',
    points: 150,
    steps: 10000,
  ),

  // Mastery.
  Achievement(
    icon: 'untouched',
    name: 'Untouched',
    description: 'Finish a level without losing a single life.',
    points: 5,
  ),
  Achievement(
    icon: 'flawless_teaching',
    name: 'Flawless Teaching',
    description: 'Three stars on all five teaching levels.',
    points: 5,
  ),
  Achievement(
    icon: 'ten_clean',
    name: 'Ten Clean',
    description: 'Three stars on 10 levels.',
    points: 10,
    steps: 10,
  ),
  Achievement(
    icon: 'hundred_clean',
    name: 'Hundred Clean',
    description: 'Three stars on 100 levels.',
    points: 20,
    steps: 100,
  ),
  Achievement(
    icon: 'untouchable',
    name: 'Untouchable',
    description: 'Three stars on 1000 levels.',
    points: 80,
    steps: 1000,
  ),
  Achievement(
    icon: 'star_hoard',
    name: 'Star Hoard',
    description: 'Collect 5000 stars.',
    points: 30,
    steps: 5000,
  ),
  // Past 10000 these cannot be incremental, so they unlock outright.
  Achievement(
    icon: 'constellation',
    name: 'Constellation',
    description: 'Collect 20000 stars.',
    points: 50,
  ),
  Achievement(
    icon: 'every_star',
    name: 'Every Star',
    description: 'Collect all 30000 stars.',
    points: 100,
  ),

  // Coins.
  Achievement(
    icon: 'pocket_change',
    name: 'Pocket Change',
    description: 'Collect 100 coins.',
    points: 5,
    steps: 100,
  ),
  Achievement(
    icon: 'sweep',
    name: 'Sweep',
    description: 'Collect every coin on a single level.',
    points: 10,
  ),
  Achievement(
    icon: 'sweeper',
    name: 'Sweeper',
    description: 'Collect every coin on 50 levels.',
    points: 25,
    steps: 50,
  ),
  Achievement(
    icon: 'coin_baron',
    name: 'Coin Baron',
    description: 'Collect 50000 coins.',
    points: 35,
  ),
  Achievement(
    icon: 'all_that_glitters',
    name: 'All That Glitters',
    description: 'Collect 250000 coins.',
    points: 60,
  ),

  // Skill.
  Achievement(
    icon: 'featherfoot',
    name: 'Featherfoot',
    description: 'Clear a level without pressing jump once.',
    points: 20,
  ),
  Achievement(
    icon: 'held_ground',
    name: 'Held Ground',
    description: 'Clear a level using three flips or fewer.',
    points: 20,
  ),
  Achievement(
    icon: 'full_tilt',
    name: 'Full Tilt',
    description: 'Three stars on a level running at full speed.',
    points: 20,
  ),
  Achievement(
    icon: 'range',
    name: 'Range',
    description: 'Three stars on levels built from six different obstacle '
        'mixes.',
    points: 25,
    steps: 6,
  ),
  Achievement(
    icon: 'every_flavour',
    name: 'Every Flavour',
    description: 'Three stars on a level from all twelve obstacle mixes.',
    points: 60,
    steps: 12,
  ),
  Achievement(
    icon: 'no_retreat',
    name: 'No Retreat',
    description: 'Clear a level after losing two lives.',
    points: 10,
  ),

  // Persistence.
  Achievement(
    icon: 'every_threat',
    name: 'Every Threat',
    description: 'Reach level 9 having met all seven kinds of obstacle.',
    points: 5,
  ),
  Achievement(
    icon: 'ten_in_a_row',
    name: 'Ten in a Row',
    description: 'Clear 10 levels without leaving the game.',
    points: 15,
    steps: 10,
  ),
  Achievement(
    icon: 'marathon',
    name: 'Marathon',
    description: 'Clear 50 levels without leaving the game.',
    points: 25,
    steps: 50,
  ),
  Achievement(
    icon: 'stubborn',
    name: 'Stubborn',
    description: 'Clear a level you have died on ten times or more.',
    points: 15,
  ),
];

void main() {
  _check();

  final dir = Directory(_outDir)..createSync(recursive: true);

  final metadata = <String>[];
  final icons = <String>[];
  for (var i = 0; i < achievements.length; i++) {
    final a = achievements[i];
    metadata.add('${a.metadataRow},${i + 1}');
    icons.add('${a.name},${a.icon}.png');
  }

  File('${dir.path}/AchievementsMetadata.csv')
      .writeAsStringSync('${metadata.join('\n')}\n');
  File('${dir.path}/AchievementsIconsMappings.csv')
      .writeAsStringSync('${icons.join('\n')}\n');

  // English only, and the default locale may not be listed, so this file has
  // nothing legal to say. Removed rather than left stale.
  final localizations = File('${dir.path}/AchievementsLocalizations.csv');
  if (localizations.existsSync()) {
    localizations.deleteSync();
    stdout.writeln('removed AchievementsLocalizations.csv '
        '(English only, and the default locale cannot be listed)');
  }

  final points = achievements.fold(0, (sum, a) => sum + a.points);
  stdout.writeln('wrote ${achievements.length} achievements, '
      '$points of $_maxPoints points');
  stdout.writeln('  ${metadata.first}');
  stdout.writeln('  ${icons.first}');
}

/// Everything Play will reject, checked before it is written rather than after
/// it is uploaded.
void _check() {
  final names = <String>{};
  var points = 0;

  for (final a in achievements) {
    void fail(String why) {
      stderr.writeln('${a.name}: $why');
      exit(1);
    }

    if (!names.add(a.name)) fail('duplicate name');
    if (a.name.contains(',')) fail('name contains a comma');
    if (a.description.contains(',')) fail('description contains a comma');
    if (a.name.length > _maxName) fail('name is over $_maxName characters');
    if (a.description.length > _maxDescription) {
      fail('description is over $_maxDescription characters');
    }
    if (a.points < 5 || a.points > 200 || a.points % 5 != 0) {
      fail('points must be 5 to 200 and a multiple of 5, not ${a.points}');
    }
    if (a.steps != null && (a.steps! < 2 || a.steps! > _maxSteps)) {
      fail('steps must be 2 to $_maxSteps, not ${a.steps}');
    }
    points += a.points;
  }

  if (points > _maxPoints) {
    stderr.writeln('$points points across the set, over the $_maxPoints Play '
        'allows');
    exit(1);
  }
}

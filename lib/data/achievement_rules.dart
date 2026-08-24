import '../game/logic/level_generator.dart' show archetypeFor;
import 'achievements.dart';
import 'progress_store.dart';

/// What one finished level says about the player.
///
/// Everything the rules need, gathered at the moment a level ends, so
/// [awardFor] is a pure function of plain values and can be tested without a
/// game, a platform or a screen.
class RunOutcome {
  const RunOutcome({
    required this.levelId,
    required this.stars,
    required this.coins,
    required this.coinsOnLevel,
    required this.runSpeed,
    required this.jumps,
    required this.flips,
    required this.deathsOnLevel,
    required this.levelsThisSession,
  });

  final int levelId;

  /// 3 for a run with every life intact, 1 for a scrappy finish.
  final int stars;
  final int coins;
  final int coinsOnLevel;
  final double runSpeed;

  /// Inputs that actually did something during the attempt.
  final int jumps;
  final int flips;

  /// How many times this level has been lost, all time.
  final int deathsOnLevel;

  /// Levels cleared since the app was opened.
  final int levelsThisSession;

  bool get clean => stars == 3;
  bool get sweptEveryCoin => coinsOnLevel > 0 && coins >= coinsOnLevel;
}

/// The top speed the pack reaches, which `full_tilt` asks for.
const double kTopRunSpeed = 280;

/// Awards everything [outcome] has earned, reading totals off [store].
///
/// Called once when a level is cleared. Every rule is cheap: the expensive
/// facts — stars, coins, levels solved — are already counted by the progress
/// store, and the archetype is a pure function of the level id.
Future<void> awardFor(
  RunOutcome outcome,
  ProgressStore store,
  AchievementsController into,
) async {
  final solved = store.solvedCount;

  // Progression. Absolute counts, so a reinstall that restores progress puts
  // these back where they belong rather than starting the climb again.
  if (outcome.levelId == 1) await into.unlock(Ach.firstSteps);
  if (_allSolved(store, 1, 5)) await into.unlock(Ach.taught);
  if (outcome.levelId >= 300) await into.unlock(Ach.pastTheRamp);
  if (outcome.levelId >= 9) await into.unlock(Ach.everyThreat);

  await into.setProgress(Ach.twoDozen, solved);
  await into.setProgress(Ach.century, solved);
  await into.setProgress(Ach.thousand, solved);
  await into.setProgress(Ach.quarter, solved);
  await into.setProgress(Ach.halfway, solved);
  await into.setProgress(Ach.pitchpole, solved);

  // Mastery.
  if (outcome.clean) await into.unlock(Ach.untouched);
  if (_allClean(store, 1, 5)) await into.unlock(Ach.flawlessTeaching);

  final cleanCount = store.cleanCount;
  await into.setProgress(Ach.tenClean, cleanCount);
  await into.setProgress(Ach.hundredClean, cleanCount);
  await into.setProgress(Ach.untouchable, cleanCount);

  final stars = store.totalStars;
  await into.setProgress(Ach.starHoard, stars);
  if (stars >= 20000) await into.unlock(Ach.constellation);
  if (stars >= 30000) await into.unlock(Ach.everyStar);

  // Coins.
  final coins = store.totalCoins;
  await into.setProgress(Ach.pocketChange, coins);
  if (coins >= 50000) await into.unlock(Ach.coinBaron);
  if (coins >= 250000) await into.unlock(Ach.allThatGlitters);

  if (outcome.sweptEveryCoin) await into.unlock(Ach.sweep);
  await into.setProgress(Ach.sweeper, store.sweptCount);

  // Skill. These read the attempt rather than the record, so they are only
  // ever earned by the run that just happened.
  if (outcome.jumps == 0) await into.unlock(Ach.featherfoot);
  if (outcome.flips <= 3) await into.unlock(Ach.heldGround);
  if (outcome.clean && outcome.runSpeed >= kTopRunSpeed) {
    await into.unlock(Ach.fullTilt);
  }
  if (outcome.stars == 1) await into.unlock(Ach.noRetreat);

  // Variety: how many different obstacle mixes have been beaten cleanly. The
  // archetype is derived from the level id, so this needs no storage of its
  // own beyond the stars already kept.
  if (outcome.clean) {
    final mixes = _cleanArchetypes(store);
    await into.setProgress(Ach.range, mixes);
    await into.setProgress(Ach.everyFlavour, mixes);
  }

  // Persistence.
  await into.setProgress(Ach.tenInARow, outcome.levelsThisSession);
  await into.setProgress(Ach.marathon, outcome.levelsThisSession);
  if (outcome.deathsOnLevel >= 10) await into.unlock(Ach.stubborn);
}

bool _allSolved(ProgressStore store, int from, int to) {
  for (var id = from; id <= to; id++) {
    if (!store.isSolved(id)) return false;
  }
  return true;
}

bool _allClean(ProgressStore store, int from, int to) {
  for (var id = from; id <= to; id++) {
    if (store.starsFor(id) < 3) return false;
  }
  return true;
}

/// How many distinct obstacle mixes have been cleared with every life intact.
int _cleanArchetypes(ProgressStore store) {
  final mixes = <String>{};
  for (final id in store.cleanLevelIds) {
    mixes.add(archetypeFor(id).name);
  }
  return mixes.length;
}

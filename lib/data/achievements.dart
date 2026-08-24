import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart' as gs;
import 'package:shared_preferences/shared_preferences.dart';

import 'games_auth.dart';

/// One achievement, as the game knows it.
///
/// [key] is ours and is what the icon files and the store CSVs are named
/// after. [androidId] is Play Games' own, assigned when the achievements were
/// imported into the console, and is the only thing the platform will answer
/// to — a display name is not an id, however much the CSV format implies it.
class AchievementSpec {
  const AchievementSpec(
    this.key,
    this.name, {
    this.steps,
    this.androidId = '',
    this.iosId = '',
  });

  final String key;

  /// Exactly the Name column of `store/achievements/AchievementsMetadata.csv`.
  /// A test asserts that, because a drifting name is a silent no-op.
  final String name;

  /// Set for incremental achievements, and equal to the Steps Needed column.
  final int? steps;

  /// The id Play Games assigned when the achievements were imported, out of
  /// the `games-ids.xml` the console hands back.
  final String androidId;

  /// Game Center's own id for the same achievement.
  ///
  /// Kept apart from [androidId] rather than reusing it, because the two
  /// stores assign ids independently and a Play id means nothing to Apple.
  /// Empty until the achievements are set up in App Store Connect, and an
  /// empty id is skipped rather than sent.
  final String iosId;

  bool get incremental => steps != null;

  /// The id for the platform this is running on, or empty if there is none.
  String get platformId =>
      defaultTargetPlatform == TargetPlatform.iOS ? iosId : androidId;

  bool get wired => platformId.isNotEmpty;
}

/// Every achievement the game can earn.
///
/// The names must match `AchievementsMetadata.csv` character for character;
/// `test/achievements_test.dart` checks that against the real file.
///
/// The `androidId` of each is the id Play Console assigned on import, taken
/// from the `games-ids.xml` it hands back. `iosId` is still empty: Game Center
/// assigns its own ids and the game is not set up there yet, so on iOS every
/// one of these is tracked and none is reported. That is the same thing that
/// happens to a player who never signs in, and it is deliberately silent.
abstract final class Ach {
  static const firstSteps = AchievementSpec(
    'first_steps',
    'First Steps',
    androidId: 'CgkIsZW9kpIHEAIQBw',
  );
  static const taught = AchievementSpec(
    'taught',
    'Taught',
    androidId: 'CgkIsZW9kpIHEAIQDA',
  );
  static const twoDozen = AchievementSpec(
    'two_dozen',
    'Two Dozen',
    steps: 25,
    androidId: 'CgkIsZW9kpIHEAIQFQ',
  );
  static const century = AchievementSpec(
    'century',
    'Century',
    steps: 100,
    androidId: 'CgkIsZW9kpIHEAIQFw',
  );
  static const pastTheRamp = AchievementSpec(
    'past_the_ramp',
    'Past the Ramp',
    androidId: 'CgkIsZW9kpIHEAIQCA',
  );
  static const thousand = AchievementSpec(
    'thousand',
    'Thousand',
    steps: 1000,
    androidId: 'CgkIsZW9kpIHEAIQAw',
  );
  static const quarter = AchievementSpec(
    'quarter',
    'Quarter',
    steps: 2500,
    androidId: 'CgkIsZW9kpIHEAIQAQ',
  );
  static const halfway = AchievementSpec(
    'halfway',
    'Halfway',
    steps: 5000,
    androidId: 'CgkIsZW9kpIHEAIQDg',
  );
  static const pitchpole = AchievementSpec(
    'pitchpole',
    'Pitchpole',
    steps: 10000,
    androidId: 'CgkIsZW9kpIHEAIQHg',
  );

  static const untouched = AchievementSpec(
    'untouched',
    'Untouched',
    androidId: 'CgkIsZW9kpIHEAIQDQ',
  );
  static const flawlessTeaching = AchievementSpec(
    'flawless_teaching',
    'Flawless Teaching',
    androidId: 'CgkIsZW9kpIHEAIQBg',
  );
  static const tenClean = AchievementSpec(
    'ten_clean',
    'Ten Clean',
    steps: 10,
    androidId: 'CgkIsZW9kpIHEAIQGw',
  );
  static const hundredClean = AchievementSpec(
    'hundred_clean',
    'Hundred Clean',
    steps: 100,
    androidId: 'CgkIsZW9kpIHEAIQGA',
  );
  static const untouchable = AchievementSpec(
    'untouchable',
    'Untouchable',
    steps: 1000,
    androidId: 'CgkIsZW9kpIHEAIQHQ',
  );
  static const starHoard = AchievementSpec(
    'star_hoard',
    'Star Hoard',
    steps: 5000,
    androidId: 'CgkIsZW9kpIHEAIQHA',
  );
  static const constellation = AchievementSpec(
    'constellation',
    'Constellation',
    androidId: 'CgkIsZW9kpIHEAIQDw',
  );
  static const everyStar = AchievementSpec(
    'every_star',
    'Every Star',
    androidId: 'CgkIsZW9kpIHEAIQGg',
  );

  static const pocketChange = AchievementSpec(
    'pocket_change',
    'Pocket Change',
    steps: 100,
    androidId: 'CgkIsZW9kpIHEAIQEw',
  );
  static const sweep = AchievementSpec(
    'sweep',
    'Sweep',
    androidId: 'CgkIsZW9kpIHEAIQBA',
  );
  static const sweeper = AchievementSpec(
    'sweeper',
    'Sweeper',
    steps: 50,
    androidId: 'CgkIsZW9kpIHEAIQCw',
  );
  static const coinBaron = AchievementSpec(
    'coin_baron',
    'Coin Baron',
    androidId: 'CgkIsZW9kpIHEAIQIA',
  );
  static const allThatGlitters = AchievementSpec(
    'all_that_glitters',
    'All That Glitters',
    androidId: 'CgkIsZW9kpIHEAIQCQ',
  );

  static const featherfoot = AchievementSpec(
    'featherfoot',
    'Featherfoot',
    androidId: 'CgkIsZW9kpIHEAIQFA',
  );
  static const heldGround = AchievementSpec(
    'held_ground',
    'Held Ground',
    androidId: 'CgkIsZW9kpIHEAIQEA',
  );
  static const fullTilt = AchievementSpec(
    'full_tilt',
    'Full Tilt',
    androidId: 'CgkIsZW9kpIHEAIQEQ',
  );
  static const range = AchievementSpec(
    'range',
    'Range',
    steps: 6,
    androidId: 'CgkIsZW9kpIHEAIQGQ',
  );
  static const everyFlavour = AchievementSpec(
    'every_flavour',
    'Every Flavour',
    steps: 12,
    androidId: 'CgkIsZW9kpIHEAIQAg',
  );
  static const noRetreat = AchievementSpec(
    'no_retreat',
    'No Retreat',
    androidId: 'CgkIsZW9kpIHEAIQCg',
  );

  static const everyThreat = AchievementSpec(
    'every_threat',
    'Every Threat',
    androidId: 'CgkIsZW9kpIHEAIQBQ',
  );
  static const tenInARow = AchievementSpec(
    'ten_in_a_row',
    'Ten in a Row',
    steps: 10,
    androidId: 'CgkIsZW9kpIHEAIQFg',
  );
  static const marathon = AchievementSpec(
    'marathon',
    'Marathon',
    steps: 50,
    androidId: 'CgkIsZW9kpIHEAIQHw',
  );
  static const stubborn = AchievementSpec(
    'stubborn',
    'Stubborn',
    androidId: 'CgkIsZW9kpIHEAIQEg',
  );

  static const all = <AchievementSpec>[
    firstSteps,
    taught,
    twoDozen,
    century,
    pastTheRamp,
    thousand,
    quarter,
    halfway,
    pitchpole,
    untouched,
    flawlessTeaching,
    tenClean,
    hundredClean,
    untouchable,
    starHoard,
    constellation,
    everyStar,
    pocketChange,
    sweep,
    sweeper,
    coinBaron,
    allThatGlitters,
    featherfoot,
    heldGround,
    fullTilt,
    range,
    everyFlavour,
    noRetreat,
    everyThreat,
    tenInARow,
    marathon,
    stubborn,
  ];
}

/// Reports earned achievements to Play Games or Game Center.
///
/// Written the way [AdsController] is: every path fails soft and nothing here
/// can make the player wait. An achievement is a note sent after the fact, so
/// a platform that is missing, signed out, offline or simply broken must cost
/// the run nothing at all.
///
/// Two rules hold this to the spirit of CLAUDE.md section 15:
///
///  * **Nothing is granted in game.** No lives, no coins, no unlocks. Play
///    draws its own toast; the game does not notice.
///  * **Earning does not require being signed in.** What is earned while
///    signed out is remembered on the device and sent the moment an account
///    appears, so signing in late costs a player nothing and signing in never
///    changes how the game plays.
class AchievementsController extends ChangeNotifier {
  static const String _unlockedKey = 'achievements.unlocked';
  static const String _stepsPrefix = 'achievements.steps.';

  SharedPreferences? _prefs;

  /// Everything earned, whether or not it has reached the platform yet.
  final Set<String> _earned = {};

  /// The step count last recorded per incremental achievement, so the same
  /// number is never sent twice.
  final Map<String, int> _steps = {};

  /// Earned but not yet accepted by the platform. Flushed on sign in.
  final Set<String> _pending = {};

  bool _sending = false;

  /// Set in tests to watch what would have been reported.
  @visibleForTesting
  List<String>? debugReported;

  Set<String> get earned => Set.unmodifiable(_earned);
  int get earnedCount => _earned.length;
  bool has(AchievementSpec spec) => _earned.contains(spec.key);

  Future<void> load() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    _earned
      ..clear()
      ..addAll(prefs.getStringList(_unlockedKey) ?? const []);
    _steps.clear();
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_stepsPrefix)) continue;
      final value = prefs.getInt(key);
      if (value != null) _steps[key.substring(_stepsPrefix.length)] = value;
    }
    // Anything earned before an account existed is still owed to the player.
    _pending
      ..clear()
      ..addAll(_earned);

    // Listened to rather than called from [GamesAuth], so the dependency only
    // ever runs this way: achievements know about the account, the account
    // knows nothing about achievements. Signing in is the moment the backlog
    // can finally be delivered.
    gamesAuth.removeListener(_onAuthChanged);
    gamesAuth.addListener(_onAuthChanged);

    notifyListeners();
  }

  bool _wasSignedIn = false;

  void _onAuthChanged() {
    final signedIn = gamesAuth.isSignedIn;
    if (signedIn && !_wasSignedIn) unawaited(flush());
    _wasSignedIn = signedIn;
  }

  /// Marks [spec] earned. Idempotent: the second call does nothing.
  Future<void> unlock(AchievementSpec spec) async {
    if (!_earned.add(spec.key)) return;
    notifyListeners();
    await _prefs?.setStringList(_unlockedKey, _earned.toList());
    _pending.add(spec.key);
    unawaited(_report(spec));
  }

  /// Records absolute progress towards an incremental achievement.
  ///
  /// Absolute rather than a delta, because the game knows the totals — how
  /// many levels are solved, how many coins are held — and a delta would drift
  /// the moment a report was lost or a run was replayed.
  Future<void> setProgress(AchievementSpec spec, int value) async {
    final target = spec.steps;
    if (target == null) return;

    final capped = value.clamp(0, target);
    if (capped <= (_steps[spec.key] ?? 0)) return;

    _steps[spec.key] = capped;
    await _prefs?.setInt('$_stepsPrefix${spec.key}', capped);

    if (capped >= target) {
      await unlock(spec);
      return;
    }
    unawaited(_report(spec, steps: capped));
  }

  /// Convenience: unlock when [reached] is true, otherwise record progress.
  Future<void> track(
    AchievementSpec spec,
    int value, {
    required int target,
  }) async {
    if (spec.incremental) return setProgress(spec, value);
    if (value >= target) return unlock(spec);
  }

  /// Sends everything earned while signed out. Called when an account appears.
  Future<void> flush() async {
    if (_pending.isEmpty) return;
    final owed = [
      for (final spec in Ach.all)
        if (_pending.contains(spec.key)) spec,
    ];
    for (final spec in owed) {
      await _report(spec);
    }
  }

  /// The only place that touches the platform.
  ///
  /// Returns without doing anything at all when there is nothing to send to:
  /// no account, no id yet, or an unsupported platform. That is the common
  /// case during development and it must be silent, not an error.
  Future<void> _report(AchievementSpec spec, {int? steps}) async {
    debugReported?.add(steps == null ? spec.key : '${spec.key}:$steps');

    if (!spec.wired || !gamesAuth.isSignedIn || _sending) return;

    _sending = true;
    try {
      final achievement = gs.Achievement(
        androidID: spec.androidId,
        iOSID: spec.iosId,
        steps: steps ?? spec.steps ?? 0,
      );
      if (steps != null) {
        await gs.Achievements.setSteps(achievement: achievement);
      } else {
        await gs.Achievements.unlock(achievement: achievement);
        _pending.remove(spec.key);
      }
    } catch (error) {
      // A note that did not arrive. It stays pending and goes again next
      // launch; nothing about the run is allowed to depend on this.
      debugPrint('Pitchpole: could not report ${spec.name} ($error)');
    } finally {
      _sending = false;
    }
  }

  /// Opens the platform's own achievement list.
  ///
  /// The game draws none of its own, deliberately. Play and Game Center each
  /// render the list, the locked ones and the progress bars already, and a
  /// copy inside the game would be a second thing to keep true — and one that
  /// would have to lie while signed out, since the platform is the only thing
  /// that knows what it has accepted.
  Future<void> show() async {
    if (!gamesAuth.isSignedIn) return;
    try {
      await gs.Achievements.showAchievements();
    } catch (error) {
      debugPrint('Pitchpole: could not open the achievements ($error)');
    }
  }

  @visibleForTesting
  Future<void> debugReset() async {
    _earned.clear();
    _steps.clear();
    _pending.clear();
    debugReported = null;
  }
}

final AchievementsController achievements = AchievementsController();

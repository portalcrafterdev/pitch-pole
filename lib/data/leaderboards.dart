import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart' as gs;
import 'package:shared_preferences/shared_preferences.dart';

import 'games_auth.dart';
import 'progress_store.dart';

/// One leaderboard, as the game knows it.
///
/// The same shape as [AchievementSpec], and for the same reason: [key] is ours
/// and names the icon file, [androidId] is the id Play Console generates when
/// the board is created, and a display name is not an id however much the
/// console's own UI implies it.
class LeaderboardSpec {
  const LeaderboardSpec(
    this.key,
    this.name, {
    required this.max,
    this.androidId = '',
    this.iosId = '',
  });

  final String key;

  /// Exactly the Name field of the board in Play Console.
  final String name;

  /// The largest score the game can produce, which is what the board's
  /// optional upper score limit should be set to. A score above this could
  /// only come from a tampered client.
  final int max;

  /// The id Play Console assigns when the leaderboard is created. Empty until
  /// the boards exist, and an empty id is skipped rather than sent — so this
  /// ships and behaves correctly before the console has heard of it.
  final String androidId;

  /// Game Center's own id for the same board. Kept apart from [androidId]
  /// because the two stores assign ids independently.
  final String iosId;

  String get platformId =>
      defaultTargetPlatform == TargetPlatform.iOS ? iosId : androidId;

  bool get wired => platformId.isNotEmpty;
}

/// Every leaderboard the game submits to. There is exactly one.
///
/// Play allows seventy and most runners spend them on times, but **every level
/// in this pack takes exactly 30 seconds** — length is `runSpeed * 30` by
/// construction, and speed is fixed for the whole level — so a clean run of
/// level 8,472 is 30.0 for every player alive. A time board here would be a
/// wall of ties that quietly ranks people by how often they died, which is not
/// what it would appear to measure.
///
/// What is left is cumulative totals, and stars is the one worth ranking: it
/// counts progress and how cleanly it was made in a single number, so it says
/// more than levels cleared and asks for more than coins. One board also keeps
/// the whole feature honest — there is a single row in the account sheet and a
/// single figure behind it, rather than a wall of near duplicates of the same
/// progress.
///
/// Only the all time span means anything, so that is the only one offered.
/// Play keeps the best score submitted in each window, so the daily board of a
/// running total would show a veteran's lifetime figure on a day they did not
/// play.
abstract final class Lb {
  /// Stars held, out of three per level.
  ///
  /// Three for finishing with every life intact, two with one lost, one for
  /// finishing at all — so the figure rises with both how far a player has got
  /// and how well they got there.
  static const starsEarned = LeaderboardSpec(
    'stars_earned',
    'Stars Earned',
    max: 30000,
    androidId: 'CgkIsZW9kpIHEAIQIQ',
  );

  static const List<LeaderboardSpec> all = [starsEarned];
}

/// Submits totals to Play Games or Game Center, and opens the platform's own
/// leaderboard screen.
///
/// Written the way [AchievementsController] is, and bound by the same two
/// rules from CLAUDE.md section 15:
///
///  * **Nothing is granted in game.** A score is a note sent after the fact.
///    There is no method here that hands anything back, and no run reads it.
///  * **Playing does not require an account.** Totals are kept on the device
///    whether signed in or not, and the latest of each is sent the moment an
///    account appears. Signing in late costs a player nothing, and never
///    signing in costs them nothing either.
///
/// Every path fails soft. No account, no id, an offline phone or a broken
/// platform all return without doing anything, because none of them is the
/// player's problem.
class LeaderboardsController extends ChangeNotifier {
  static const String _sentPrefix = 'leaderboards.sent.';

  SharedPreferences? _prefs;

  /// The highest value actually accepted by the platform, per board, so the
  /// same number is never sent twice.
  final Map<String, int> _sent = {};

  /// The latest value the game knows, per board, whether or not it has been
  /// delivered. This is what is flushed when an account appears.
  final Map<String, int> _latest = {};

  bool _sending = false;

  /// Set in tests to watch what would have been submitted.
  @visibleForTesting
  List<String>? debugSubmitted;

  /// Whether the platform screen can be opened at all. Without an account
  /// there is nothing to show, so the row is not offered.
  bool get canShow => gamesAuth.isSignedIn;

  Future<void> load() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    _sent.clear();
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_sentPrefix)) continue;
      final value = prefs.getInt(key);
      if (value != null) _sent[key.substring(_sentPrefix.length)] = value;
    }

    // Listened to rather than called from [GamesAuth], so the dependency runs
    // one way only: the boards know about the account, the account knows
    // nothing about the boards.
    gamesAuth.removeListener(_onAuthChanged);
    gamesAuth.addListener(_onAuthChanged);

    notifyListeners();
  }

  bool _wasSignedIn = false;

  void _onAuthChanged() {
    final signedIn = gamesAuth.isSignedIn;
    if (signedIn && !_wasSignedIn) unawaited(flush());
    _wasSignedIn = signedIn;
    notifyListeners();
  }

  /// Sends the board's current figure, read off [store].
  ///
  /// Called when a level is cleared. The star count is an absolute total
  /// rather than a delta, because the game already knows the total and a delta
  /// would drift the moment a submission was lost or a level was replayed.
  Future<void> submitTotals(ProgressStore store) async {
    await submit(Lb.starsEarned, store.totalStars);
  }

  /// Records [value] for [spec] and sends it if it is worth sending.
  ///
  /// Play keeps the best score itself, so re-sending a figure it already holds
  /// changes nothing — this skips it to keep the call count honest rather than
  /// because the platform would be confused by it.
  Future<void> submit(LeaderboardSpec spec, int value) async {
    final capped = value.clamp(0, spec.max);
    _latest[spec.key] = capped;
    if (capped <= (_sent[spec.key] ?? -1)) return;
    await _post(spec, capped);
  }

  /// Sends the latest figure for every board. Called when an account appears,
  /// so a player who played for a week signed out arrives with real numbers
  /// rather than an empty row.
  Future<void> flush() async {
    for (final spec in Lb.all) {
      final value = _latest[spec.key];
      if (value == null) continue;
      if (value <= (_sent[spec.key] ?? -1)) continue;
      await _post(spec, value);
    }
  }

  /// The only place that touches the platform.
  Future<void> _post(LeaderboardSpec spec, int value) async {
    debugSubmitted?.add('${spec.key}:$value');

    if (!spec.wired || !gamesAuth.isSignedIn || _sending) return;

    _sending = true;
    try {
      await gs.Leaderboards.submitScore(
        score: gs.Score(
          androidLeaderboardID: spec.androidId,
          iOSLeaderboardID: spec.iosId,
          value: value,
        ),
      );
      _sent[spec.key] = value;
      await _prefs?.setInt('$_sentPrefix${spec.key}', value);
    } catch (error) {
      // A figure that did not arrive. It stays in [_latest] and goes again on
      // the next level cleared or the next sign in; nothing in a run depends
      // on this having worked.
      debugPrint('Pitchpole: could not submit ${spec.name} ($error)');
    } finally {
      _sending = false;
    }
  }

  /// Opens the platform's own leaderboard screen.
  ///
  /// The game draws no board of its own. Play and Game Center each render the
  /// list, the time spans and the friends toggle themselves, which is both far
  /// less to build and the screen players already know. Passing no [spec]
  /// shows the list, which is the one board.
  Future<void> show({LeaderboardSpec? spec}) async {
    if (!gamesAuth.isSignedIn) return;
    try {
      await gs.Leaderboards.showLeaderboards(
        androidLeaderboardID: spec?.androidId ?? '',
        iOSLeaderboardID: spec?.iosId ?? '',
        // Only span that says anything true for a pack of cumulative totals.
        // See the note on [Lb].
        timeScope: gs.TimeScope.allTime,
      );
    } catch (error) {
      debugPrint('Pitchpole: could not open the leaderboards ($error)');
    }
  }

  @visibleForTesting
  Future<void> debugReset() async {
    _sent.clear();
    _latest.clear();
    debugSubmitted = null;
  }
}

final LeaderboardsController leaderboards = LeaderboardsController();

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart' as gs;

import 'games_auth.dart';
import 'progress_store.dart';

/// Carries progress between a player's devices through Play Games or Game
/// Center, so a new phone is not a fresh start.
///
/// Written the way [AdsController] and [AchievementsController] are, and bound
/// by the same rule: **nothing here may make the player wait.** Every upload is
/// fire and forget, every failure is silent, and a level never blocks on a
/// network. A player with no signal plays exactly the game a player with five
/// bars plays.
///
/// Three things keep this from being the usual lost-progress story:
///
///  * **It merges, it never overwrites.** [ProgressStore.mergeSnapshot] keeps
///    the better side of every value. Signing in cannot cost a player anything
///    they had on the device, which is the failure that makes people uninstall
///    a game.
///  * **The device is the source of truth.** The cloud is a copy. If the
///    download is missing, stale or corrupt the game carries on with what is on
///    the phone and simply uploads again.
///  * **Signed out is unchanged.** No account, no upload, no difference to how
///    the game plays. Progress has always lived in `shared_preferences` and
///    still does.
class CloudSaveController extends ChangeNotifier {
  /// Play's name rules: 1 to 100 characters from a-z, A-Z, 0-9, `-`, `.`, `_`
  /// and `~`. One save slot, because the game has one profile.
  static const String _slot = 'pitchpole.progress';

  /// How long an upload waits for the run to settle.
  ///
  /// Finishing a level fires a save, and a player rattling through short levels
  /// would otherwise upload every thirty seconds for nothing. The last write
  /// inside this window is the one that goes.
  static const Duration _quiet = Duration(seconds: 5);

  Timer? _pending;
  bool _busy = false;

  /// Whether the last download actually produced a save. Read by nothing in a
  /// run; here so the account sheet can say something true.
  bool _restored = false;
  bool get hasRestored => _restored;

  /// Test seam: what would have been uploaded, without a platform to send it.
  @visibleForTesting
  List<String>? debugUploaded;

  /// Test seam: stands in for what the platform would hand back.
  @visibleForTesting
  String? debugDownload;

  bool get _canSync => gamesAuth.isSignedIn;

  /// Starts listening for an account appearing.
  ///
  /// Listened to rather than called from [GamesAuth], so the dependency runs
  /// one way only: saving knows about the account, the account knows nothing
  /// about saving.
  void start() {
    gamesAuth.removeListener(_onAuthChanged);
    gamesAuth.addListener(_onAuthChanged);
    _wasSignedIn = gamesAuth.isSignedIn;
    if (_wasSignedIn) unawaited(restore());
  }

  bool _wasSignedIn = false;

  void _onAuthChanged() {
    final signedIn = gamesAuth.isSignedIn;
    // The moment an account appears is the moment there is something to pull
    // down. Restoring first and uploading after means a device that has been
    // played signed out contributes its progress rather than being flattened
    // by whatever the cloud happened to hold.
    if (signedIn && !_wasSignedIn) {
      unawaited(restore().then((_) => save()));
    }
    _wasSignedIn = signedIn;
  }

  /// Downloads the save and folds it into what is already on the device.
  ///
  /// Safe to call at any time and safe to call twice: the merge keeps the
  /// better of each value, so running it again changes nothing.
  Future<void> restore() async {
    if (!_canSync || _busy) return;
    _busy = true;
    try {
      final raw = debugDownload ?? await gs.SaveGame.loadGame(name: _slot);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('Pitchpole: cloud save is not a save, ignoring it');
        return;
      }
      await progressStore.mergeSnapshot(decoded);
      _restored = true;
      notifyListeners();
    } catch (error) {
      // A save that did not arrive, or arrived broken. The device's own
      // progress is untouched and authoritative, so there is nothing to do
      // but carry on and try again next time.
      debugPrint('Pitchpole: could not restore progress ($error)');
    } finally {
      _busy = false;
    }
  }

  /// Queues an upload. Returns immediately; the write happens later.
  void scheduleSave() {
    if (!_canSync) return;
    _pending?.cancel();
    _pending = Timer(_quiet, () => unawaited(save()));
  }

  /// Uploads the device's progress now.
  Future<void> save() async {
    _pending?.cancel();
    _pending = null;
    if (!_canSync || _busy) return;

    final data = jsonEncode(progressStore.toSnapshot());
    debugUploaded?.add(data);

    _busy = true;
    try {
      await gs.SaveGame.saveGame(
        data: data,
        name: _slot,
        description: '${progressStore.solvedCount} levels, '
            '${progressStore.totalStars} stars',
      );
    } catch (error) {
      debugPrint('Pitchpole: could not save progress ($error)');
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _pending?.cancel();
    gamesAuth.removeListener(_onAuthChanged);
    super.dispose();
  }

  @visibleForTesting
  void debugReset() {
    _pending?.cancel();
    _pending = null;
    _busy = false;
    _restored = false;
    debugUploaded = null;
    debugDownload = null;
  }
}

final CloudSaveController cloudSave = CloudSaveController();

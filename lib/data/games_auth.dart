import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which service this platform signs in against. There is only ever one, and
/// it is decided by the platform rather than offered as a choice.
enum GamesService {
  playGames('Play Games', 'Google Play Games'),
  gameCenter('Game Center', 'Apple Game Center');

  const GamesService(this.short, this.long);

  final String short;
  final String long;
}

enum GamesAuthState { signedOut, signingIn, signedIn }

/// Signing in to Google Play Games or Apple Game Center.
///
/// This is identity and nothing else. Stars, times and coins stay in
/// [ProgressStore] on the device, the game still has no backend, and nothing
/// in the run is gated behind being signed in. Being signed out is a fully
/// supported way to play the whole game.
///
/// Everything here fails soft. The platform side needs console configuration
/// that a debug build usually does not have, so every call is wrapped: a
/// failure leaves the player signed out with a readable reason, never an
/// unhandled exception on the way to the menu.
class GamesAuth extends ChangeNotifier {
  static const String _optedInKey = 'games.optedIn';
  static const String _nameKey = 'games.playerName';

  /// How long to wait for the platform to say who is *already* signed in.
  /// Nobody is looking at a dialog during this, so it can be short: the menu
  /// is usable throughout and just updates when the answer lands.
  static const Duration _queryTimeout = Duration(seconds: 10);

  /// How long to wait for an interactive sign in. Much longer, because this
  /// one spans a full screen Google or Apple account chooser that the player
  /// is reading: timing it out on the same ten seconds would report a failure
  /// while the player was still halfway through picking an account, and then
  /// contradict itself when the real answer arrived.
  static const Duration _signInTimeout = Duration(minutes: 5);

  SharedPreferences? _prefs;

  GamesAuthState _state = GamesAuthState.signedOut;
  String? _playerName;
  Uint8List? _playerIcon;
  String? _lastError;
  String? _lastErrorDetail;

  /// Whether the player has ever asked to be signed in. Until they have, the
  /// game never touches the platform, so a fresh install gets no dialog and no
  /// account prompt it did not ask for.
  bool _optedIn = false;

  GamesAuthState get state => _state;
  bool get isSignedIn => _state == GamesAuthState.signedIn;
  bool get isBusy => _state == GamesAuthState.signingIn;

  /// The display name, from the platform if it has answered and from the last
  /// session's cache if it has not. Lets the button say who is signed in
  /// straight away on a cold launch instead of flickering through "Sign in".
  String? get playerName => _playerName;

  /// The player's avatar, if the platform gave one.
  Uint8List? get playerIcon => _playerIcon;

  /// Why the last sign in attempt failed, in one line. Null if the last
  /// attempt worked or there has not been one.
  String? get lastError => _lastError;

  /// The same failure at length, for a dialog. The one line version has to sit
  /// under a button on a landscape phone, which is not enough room to say what
  /// to actually do about it.
  String? get lastErrorDetail => _lastErrorDetail;

  bool get optedIn => _optedIn;

  GamesService get service => defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS
      ? GamesService.gameCenter
      : GamesService.playGames;

  /// Whether the platform can sign in at all. Android and iOS are the only
  /// platforms the game ships on, so anything else gets a button that
  /// explains itself rather than one that is missing.
  bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Reads the cached name and, if the player has signed in before, asks the
  /// platform who is signed in now. Safe to call before [runApp] finishes and
  /// safe to await or not.
  Future<void> load() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    _optedIn = prefs.getBool(_optedInKey) ?? false;
    _playerName = prefs.getString(_nameKey);
    if (_optedIn && _playerName != null) {
      // Optimistic: the platform usually confirms this within a second, and
      // showing the name immediately beats showing "Sign in" and then
      // swapping it out under the player's thumb.
      _state = GamesAuthState.signedIn;
    }
    notifyListeners();

    if (_optedIn && isSupported) await refresh();
  }

  /// Asks the platform who is signed in, without ever showing a dialog.
  Future<void> refresh() async {
    if (!isSupported) return;
    final player = await _currentPlayer();
    if (player == null) {
      // Only demote if we were claiming a session. A failure here is not a
      // reason to shout at the player: they may simply be offline.
      if (_state == GamesAuthState.signedIn) _setSignedOut(keepOptIn: true);
      return;
    }
    await _setSignedIn(player);
  }

  /// The explicit sign in, from the button. This is the only path allowed to
  /// put an account dialog in front of the player.
  Future<bool> signIn() async {
    if (_state == GamesAuthState.signingIn) return false;

    if (!isSupported) {
      _fail(
        'Sign in needs a phone.',
        'Play Games and Game Center only exist on Android and iOS.',
      );
      return false;
    }

    _lastError = null;
    _lastErrorDetail = null;
    _state = GamesAuthState.signingIn;
    notifyListeners();

    try {
      await GameAuth.signIn().timeout(_signInTimeout);
      final player = await _currentPlayer();
      if (player == null) {
        _failConfiguration();
        return false;
      }
      await _setSignedIn(player);
      return true;
    } on TimeoutException {
      _fail(
        '${service.short} did not answer.',
        'The sign in was left open long enough that the game stopped waiting '
            'for it. Check the connection and try again.',
      );
      return false;
    } catch (error) {
      _describe(error);
      return false;
    }
  }

  /// Settles a sign in the platform walked away from.
  ///
  /// Play Games puts its own full screen flow over the game, and backing out
  /// of it does not always complete the call the plugin is waiting on. Without
  /// this the button is left reading SIGNING IN with a spinner in it until
  /// [_signInTimeout] gives up five minutes later, which looks exactly like
  /// the game having hung. Backing out of a sign in is an ordinary thing to
  /// do, so it cannot cost five minutes of a dead button.
  ///
  /// Called when the app comes back to the front, which is the moment that
  /// flow has closed. Asking the platform is what decides the answer rather
  /// than assuming a cancel: coming back having actually signed in is just as
  /// likely, and that is the same question [refresh] asks.
  Future<void> resolvePendingSignIn() async {
    if (_state != GamesAuthState.signingIn) return;

    final player = await _currentPlayer();

    // The call the button is waiting on may have landed while the platform was
    // answering this one. It knows more than we do, so it wins.
    if (_state != GamesAuthState.signingIn) return;

    if (player == null) {
      _fail(
        'Sign in was not finished.',
        'The ${service.short} screen closed without signing in. That is '
            'usually because it was dismissed, so nothing is wrong and you can '
            'tap the button again whenever you like.',
      );
      return;
    }
    await _setSignedIn(player);
  }

  /// Stops the game reconnecting on the next launch.
  ///
  /// Deliberately not called "sign out": neither Play Games nor Game Center
  /// lets a game sign an account out of the device, so all this can honestly
  /// do is forget the account here. The UI says as much.
  Future<void> forget() async {
    _setSignedOut(keepOptIn: false);
    await _prefs?.remove(_nameKey);
    await _prefs?.setBool(_optedInKey, false);
  }

  Future<PlayerData?> _currentPlayer() async {
    try {
      // The stream reports an unauthenticated player as null rather than as an
      // error, so a plain read is enough to tell signed in from signed out.
      return await GameAuth.player.first.timeout(_queryTimeout);
    } catch (_) {
      return null;
    }
  }

  Future<void> _setSignedIn(PlayerData player) async {
    _state = GamesAuthState.signedIn;
    _playerName = player.displayName;
    _playerIcon = _decodeIcon(player.iconImage);
    _lastError = null;
    _lastErrorDetail = null;
    _optedIn = true;
    notifyListeners();

    await _prefs?.setBool(_optedInKey, true);
    await _prefs?.setString(_nameKey, player.displayName);
  }

  void _setSignedOut({required bool keepOptIn}) {
    _state = GamesAuthState.signedOut;
    _playerName = null;
    _playerIcon = null;
    if (!keepOptIn) _optedIn = false;
    notifyListeners();
  }

  void _fail(String message, String detail) {
    _state = GamesAuthState.signedOut;
    _lastError = message;
    _lastErrorDetail = detail;
    notifyListeners();
  }

  static Uint8List? _decodeIcon(String? base64Png) {
    if (base64Png == null || base64Png.isEmpty) return null;
    try {
      return base64Decode(base64Png);
    } catch (_) {
      return null;
    }
  }

  /// Nearly every first run failure is the console side not being set up yet.
  ///
  /// It is worth naming precisely, because the symptom looks like a bug in the
  /// game rather than a missing account: the platform opens its own full
  /// screen sheet, finds no game registered under this package name to sign
  /// into, shows no account list at all, and eventually closes itself. From
  /// inside the game that is indistinguishable from nothing having happened.
  void _failConfiguration() => service == GamesService.playGames
      ? _fail(
          'Play Games is not set up for this build.',
          'Play Games showed no accounts because there is no Play Games '
              'Services project registered for this package name yet, so '
              'there is nothing for it to sign in to.\n\n'
              'Setting one up needs three things, in the Play Console: a Play '
              'Games Services project, its project number in '
              'android/app/src/main/res/values/game_ids.xml, and an Android '
              'credential holding the signing certificate this build was '
              'signed with. A debug build and a release build have different '
              'certificates, so both need one.',
        )
      : _fail(
          'Game Center is not set up for this build.',
          'Game Center showed no account because this app is not registered '
              'with it yet. It needs Game Center enabled on the App ID in the '
              'Apple Developer portal, and the Game Center capability added '
              'to the Runner target in Xcode. Check as well that the device '
              'itself is signed in to Game Center in Settings.',
        );

  void _describe(Object error) {
    final text = error.toString();
    if (text.contains('MissingPluginException')) {
      _fail(
        '${service.short} is not available in this build.',
        'The platform side of ${service.long} is missing, which normally '
            'means the app is running somewhere it does not ship.',
      );
      return;
    }
    // Play Games reports a cancelled sheet as an authentication failure too,
    // so this covers both "changed my mind" and "not configured". The second
    // is overwhelmingly the likelier of the two on a first attempt.
    if (text.contains('failed_to_authenticate') ||
        text.contains('not_authenticated')) {
      _failConfiguration();
      return;
    }
    _fail(
      'Could not sign in to ${service.short}.',
      text,
    );
  }

  /// Test seam. Puts the object in the signed in state without a platform.
  @visibleForTesting
  void debugSetSignedIn(String name) {
    _state = GamesAuthState.signedIn;
    _playerName = name;
    _lastError = null;
    notifyListeners();
  }
}

final GamesAuth gamesAuth = GamesAuth();

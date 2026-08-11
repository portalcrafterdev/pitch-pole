import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How touch drives the game. The two are exclusive on purpose: if buttons are
/// on, tapping anywhere else does nothing, and if halves are on there are no
/// buttons to miss. Mixing them means a thumb resting near a button flips you
/// into a blade.
enum ControlScheme {
  /// The left half of the screen flips, the right half jumps.
  halves,

  /// Explicit pads: up and down on the left, jump on the right.
  buttons;

  static ControlScheme fromName(String? value) =>
      values.firstWhere((s) => s.name == value, orElse: () => halves);
}

/// Stars per level and the settings toggles. No backend, no account.
class ProgressStore extends ChangeNotifier {
  static const String _starsPrefix = 'stars.';
  static const String _bestPrefix = 'best.';
  static const String _coinsPrefix = 'coins.';
  static const String _hapticsKey = 'settings.haptics';
  static const String _soundKey = 'settings.sound';
  static const String _musicKey = 'settings.music';
  static const String _soundVolumeKey = 'settings.soundVolume';
  static const String _musicVolumeKey = 'settings.musicVolume';
  static const String _controlsKey = 'settings.controls';

  SharedPreferences? _prefs;
  final Map<int, int> _stars = {};
  final Map<int, double> _bestSeconds = {};

  /// Most coins picked up on a single run of a level.
  final Map<int, int> _bestCoins = {};
  bool _haptics = true;
  bool _sound = true;
  bool _music = true;

  /// Where each slider sits, from 0 to 1. This is the player's own level, on
  /// top of the mix in [Mix]: that decides how the sounds sit against each
  /// other, these decide how loud the two groups are overall.
  double _soundVolume = 1;
  double _musicVolume = 1;
  ControlScheme _controls = ControlScheme.halves;

  bool get hapticsEnabled => _haptics;
  bool get soundEnabled => _sound;
  bool get musicEnabled => _music;
  double get soundVolume => _soundVolume;
  double get musicVolume => _musicVolume;
  ControlScheme get controlScheme => _controls;

  Future<void> load() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    _stars.clear();
    _bestSeconds.clear();
    _bestCoins.clear();
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_starsPrefix)) {
        final id = int.tryParse(key.substring(_starsPrefix.length));
        final stars = prefs.getInt(key);
        if (id != null && stars != null) _stars[id] = stars;
      } else if (key.startsWith(_bestPrefix)) {
        final id = int.tryParse(key.substring(_bestPrefix.length));
        final best = prefs.getDouble(key);
        if (id != null && best != null) _bestSeconds[id] = best;
      } else if (key.startsWith(_coinsPrefix)) {
        final id = int.tryParse(key.substring(_coinsPrefix.length));
        final coins = prefs.getInt(key);
        if (id != null && coins != null) _bestCoins[id] = coins;
      }
    }
    _haptics = prefs.getBool(_hapticsKey) ?? true;
    _sound = prefs.getBool(_soundKey) ?? true;
    _music = prefs.getBool(_musicKey) ?? true;
    _soundVolume = (prefs.getDouble(_soundVolumeKey) ?? 1).clamp(0.0, 1.0);
    _musicVolume = (prefs.getDouble(_musicVolumeKey) ?? 1).clamp(0.0, 1.0);
    _controls = ControlScheme.fromName(prefs.getString(_controlsKey));
    notifyListeners();
  }

  int starsFor(int levelId) => _stars[levelId] ?? 0;

  bool isSolved(int levelId) => starsFor(levelId) > 0;

  /// Level 1 is always open. Every other level opens once the one before it
  /// has been solved.
  bool isUnlocked(int levelId) => levelId <= 1 || isSolved(levelId - 1);

  int get totalStars => _stars.values.fold(0, (sum, s) => sum + s);

  int get solvedCount => _stars.length;

  /// The level the Play button should drop the player into.
  int nextLevel(int levelCount) {
    for (var id = 1; id <= levelCount; id++) {
      if (!isSolved(id)) return id;
    }
    return levelCount;
  }

  /// Personal best finishing time, or null if never finished.
  double? bestSecondsFor(int levelId) => _bestSeconds[levelId];

  /// Most coins picked up on one run of a level.
  int bestCoinsFor(int levelId) => _bestCoins[levelId] ?? 0;

  int get totalCoins => _bestCoins.values.fold(0, (sum, c) => sum + c);

  /// Records a finish, keeping the best star count and the fastest time. The
  /// two are tracked separately: a slow clean run keeps its 3 stars, a fast
  /// scrappy one keeps its time.
  Future<void> record(
    int levelId,
    int stars,
    double seconds, {
    int coins = 0,
  }) async {
    final best = _bestSeconds[levelId];
    final improvedTime = best == null || seconds < best;
    final improvedStars = stars > starsFor(levelId);
    // Kept apart from the other two on purpose: a run that sweeps every coin
    // slowly should keep its coins, and a fast scrappy one should keep its
    // time.
    final improvedCoins = coins > bestCoinsFor(levelId);
    if (!improvedTime && !improvedStars && !improvedCoins) return;

    if (improvedStars) _stars[levelId] = stars;
    if (improvedTime) _bestSeconds[levelId] = seconds;
    if (improvedCoins) _bestCoins[levelId] = coins;
    notifyListeners();

    if (improvedStars) {
      await _prefs?.setInt('$_starsPrefix$levelId', stars);
    }
    if (improvedTime) {
      await _prefs?.setDouble('$_bestPrefix$levelId', seconds);
    }
    if (improvedCoins) {
      await _prefs?.setInt('$_coinsPrefix$levelId', coins);
    }
  }

  Future<void> setHaptics(bool enabled) async {
    if (_haptics == enabled) return;
    _haptics = enabled;
    notifyListeners();
    await _prefs?.setBool(_hapticsKey, enabled);
  }

  Future<void> setSound(bool enabled) async {
    if (_sound == enabled) return;
    _sound = enabled;
    notifyListeners();
    await _prefs?.setBool(_soundKey, enabled);
  }

  Future<void> setMusic(bool enabled) async {
    if (_music == enabled) return;
    _music = enabled;
    notifyListeners();
    await _prefs?.setBool(_musicKey, enabled);
  }

  /// Both sliders notify on every drag, which is what makes the change
  /// audible while the thumb is still moving, and only write to disk when the
  /// value has actually moved.
  Future<void> setSoundVolume(double value) async {
    final level = value.clamp(0.0, 1.0);
    if (_soundVolume == level) return;
    _soundVolume = level;
    notifyListeners();
    await _prefs?.setDouble(_soundVolumeKey, level);
  }

  Future<void> setMusicVolume(double value) async {
    final level = value.clamp(0.0, 1.0);
    if (_musicVolume == level) return;
    _musicVolume = level;
    notifyListeners();
    await _prefs?.setDouble(_musicVolumeKey, level);
  }

  Future<void> setControlScheme(ControlScheme scheme) async {
    if (_controls == scheme) return;
    _controls = scheme;
    notifyListeners();
    await _prefs?.setString(_controlsKey, scheme.name);
  }

  Future<void> resetProgress() async {
    final ids = {..._stars.keys, ..._bestSeconds.keys, ..._bestCoins.keys};
    _stars.clear();
    _bestSeconds.clear();
    _bestCoins.clear();
    notifyListeners();
    for (final id in ids) {
      await _prefs?.remove('$_starsPrefix$id');
      await _prefs?.remove('$_bestPrefix$id');
      await _prefs?.remove('$_coinsPrefix$id');
    }
  }
}

final ProgressStore progressStore = ProgressStore();

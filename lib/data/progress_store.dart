import 'dart:ui' show Offset, Size;

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

/// The three pads of [ControlScheme.buttons].
///
/// Where each one sits is the player's to decide. Thumbs are not the same
/// length, phones are not the same width, and a left handed player wants the
/// pair and the jump swapped over — none of which one fixed layout can answer.
enum ControlPad {
  ceiling(Offset(0.075, 0.62), 62),
  floor(Offset(0.075, 0.84), 62),
  jump(Offset(0.915, 0.80), 84);

  const ControlPad(this.home, this.size);

  /// Where the pad sits until it is moved, as a fraction of the screen.
  ///
  /// A fraction rather than a point, because a phone held sideways is anywhere
  /// from 320 to 500 points tall, and a saved point would put a pad off the
  /// edge of any screen smaller than the one it was placed on.
  final Offset home;

  /// Diameter in logical pixels before the player has scaled it. Jump is the
  /// larger of the two, because it is the input pressed most often and the
  /// worst one to miss.
  final double size;
}

/// How much room is kept along the left, right and bottom edges, in logical
/// pixels.
///
/// Not tidiness. The game runs full bleed, so all three of those edges belong
/// to the system's back and home gestures, and a pad overlapping one loses
/// presses to Android — silently, and only sometimes, which is the worst way
/// for an input to fail. It was 10, and a pad at the left edge could not be
/// tapped at all on a phone with gesture navigation.
const double kPadEdgeMargin = 26;

/// The bottom edge, kept as its own name because it is the one that costs a
/// jump rather than a flip.
const double kPadBottomMargin = kPadEdgeMargin;

/// The top edge, which no gesture claims: the status bar is hidden while the
/// game is running, so a pad up there only has to stay on screen.
const double kPadTopMargin = 10;

/// How far a pad may be scaled.
///
/// The floor is a pad still comfortably bigger than a fingertip; the ceiling
/// is one that covers a good part of a landscape phone, which is a fair thing
/// to want if you are playing with the phone flat on a table. Neither end is
/// a judgement about what plays well — that is the player's to make.
const double kMinPadScale = 0.6;
const double kMaxPadScale = 1.8;

/// Pulls a pad's fractional spot back until the whole pad is on screen and
/// clear of the gesture strip.
///
/// Takes the diameter rather than the pad, because a pad's size is the
/// player's to change and a stale one would clamp against a circle that is no
/// longer there.
///
/// Applied on every layout rather than only when a pad is dropped, so a layout
/// arranged on a tablet still has three reachable pads on a phone.
Offset clampPadSpot(double diameter, Offset spot, Size screen) {
  if (screen.width <= 0 || screen.height <= 0) return spot;
  final half = diameter / 2;
  final minX = (half + kPadEdgeMargin) / screen.width;
  final minY = (half + kPadTopMargin) / screen.height;
  final maxX = 1 - minX;
  final maxY = 1 - (half + kPadBottomMargin) / screen.height;
  return Offset(
    minX > maxX ? 0.5 : spot.dx.clamp(minX, maxX),
    minY > maxY ? 0.5 : spot.dy.clamp(minY, maxY),
  );
}

/// Stars per level and the settings toggles. No backend, no account.
class ProgressStore extends ChangeNotifier {
  static const String _starsPrefix = 'stars.';
  static const String _bestPrefix = 'best.';
  static const String _coinsPrefix = 'coins.';
  static const String _coinTotalPrefix = 'coinsOf.';
  static const String _deathsPrefix = 'deaths.';
  static const String _streakKey = 'streak.count';
  static const String _streakDayKey = 'streak.lastDay';
  static const String _hapticsKey = 'settings.haptics';
  static const String _soundKey = 'settings.sound';
  static const String _musicKey = 'settings.music';
  static const String _soundVolumeKey = 'settings.soundVolume';
  static const String _musicVolumeKey = 'settings.musicVolume';
  static const String _controlsKey = 'settings.controls';
  static const String _padPrefix = 'settings.pad.';

  SharedPreferences? _prefs;
  final Map<int, int> _stars = {};
  final Map<int, double> _bestSeconds = {};

  /// Most coins picked up on a single run of a level.
  final Map<int, int> _bestCoins = {};

  /// How many coins each level actually holds, so a swept level can be told
  /// from a nearly swept one without loading the pack.
  final Map<int, int> _coinTotals = {};

  /// Lives lost per level, all time. Only an achievement reads this.
  final Map<int, int> _deaths = {};

  /// Days played in a row, and the day the last one was counted.
  ///
  /// The day is stored as a count of local days rather than a timestamp, so
  /// "did you play today" means the player's today and not UTC's. A player in
  /// Kolkata who plays at 1am should not be told they missed a day because it
  /// was still yesterday in Greenwich.
  int _streak = 0;
  int? _lastPlayedDay;
  bool _haptics = true;
  bool _sound = true;
  bool _music = true;

  /// Where each slider sits, from 0 to 1. This is the player's own level, on
  /// top of the mix in [Mix]: that decides how the sounds sit against each
  /// other, these decide how loud the two groups are overall.
  double _soundVolume = 1;
  double _musicVolume = 1;
  ControlScheme _controls = ControlScheme.halves;

  /// Only the pads the player has actually moved or resized. A pad missing
  /// from these sits at its [ControlPad.home] at its [ControlPad.size], so the
  /// defaults can be changed later without having to migrate anybody's saved
  /// layout.
  final Map<ControlPad, Offset> _padSpots = {};
  final Map<ControlPad, double> _padScales = {};

  bool get hapticsEnabled => _haptics;
  bool get soundEnabled => _sound;
  bool get musicEnabled => _music;
  double get soundVolume => _soundVolume;
  double get musicVolume => _musicVolume;
  ControlScheme get controlScheme => _controls;

  /// Where a pad sits, as a fraction of the screen.
  Offset padSpot(ControlPad pad) => _padSpots[pad] ?? pad.home;

  /// How much bigger or smaller than standard the player has made a pad.
  double padScale(ControlPad pad) => _padScales[pad] ?? 1;

  /// The pad's drawn and pressed diameter, in logical pixels.
  double padDiameter(ControlPad pad) => pad.size * padScale(pad);

  /// Whether the player has changed anything, so the arrange screen knows
  /// whether it has a layout worth offering to put back.
  bool get padsMoved => _padSpots.isNotEmpty || _padScales.isNotEmpty;

  Future<void> load() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    _stars.clear();
    _bestSeconds.clear();
    _bestCoins.clear();
    _coinTotals.clear();
    _deaths.clear();
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_starsPrefix)) {
        final id = int.tryParse(key.substring(_starsPrefix.length));
        final stars = prefs.getInt(key);
        if (id != null && stars != null) _stars[id] = stars;
      } else if (key.startsWith(_bestPrefix)) {
        final id = int.tryParse(key.substring(_bestPrefix.length));
        final best = prefs.getDouble(key);
        if (id != null && best != null) _bestSeconds[id] = best;
      } else if (key.startsWith(_coinTotalPrefix)) {
        final id = int.tryParse(key.substring(_coinTotalPrefix.length));
        final total = prefs.getInt(key);
        if (id != null && total != null) _coinTotals[id] = total;
      } else if (key.startsWith(_deathsPrefix)) {
        final id = int.tryParse(key.substring(_deathsPrefix.length));
        final deaths = prefs.getInt(key);
        if (id != null && deaths != null) _deaths[id] = deaths;
      } else if (key.startsWith(_coinsPrefix)) {
        final id = int.tryParse(key.substring(_coinsPrefix.length));
        final coins = prefs.getInt(key);
        if (id != null && coins != null) _bestCoins[id] = coins;
      }
    }
    _streak = prefs.getInt(_streakKey) ?? 0;
    _lastPlayedDay = prefs.getInt(_streakDayKey);
    _haptics = prefs.getBool(_hapticsKey) ?? true;
    _sound = prefs.getBool(_soundKey) ?? true;
    _music = prefs.getBool(_musicKey) ?? true;
    _soundVolume = (prefs.getDouble(_soundVolumeKey) ?? 1).clamp(0.0, 1.0);
    _musicVolume = (prefs.getDouble(_musicVolumeKey) ?? 1).clamp(0.0, 1.0);
    _controls = ControlScheme.fromName(prefs.getString(_controlsKey));

    _padSpots.clear();
    _padScales.clear();
    for (final pad in ControlPad.values) {
      final x = prefs.getDouble('$_padPrefix${pad.name}.x');
      final y = prefs.getDouble('$_padPrefix${pad.name}.y');
      // Both or neither. Half a coordinate is a half written layout, and
      // pairing it with a default would put the pad somewhere nobody chose.
      if (x != null && y != null) _padSpots[pad] = Offset(x, y);

      final scale = prefs.getDouble('$_padPrefix${pad.name}.s');
      if (scale != null) {
        _padScales[pad] = scale.clamp(kMinPadScale, kMaxPadScale);
      }
    }
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

  /// Levels finished with every life intact.
  int get cleanCount => _stars.values.where((s) => s == 3).length;

  /// The ids of those, so a caller can ask what kind of levels they were.
  Iterable<int> get cleanLevelIds =>
      _stars.entries.where((e) => e.value == 3).map((e) => e.key);

  /// Levels where every coin has been picked up on a single run.
  ///
  /// Counted against [_coinTotals], which is what the level actually holds, so
  /// a level is only swept when nothing was left behind.
  int get sweptCount {
    var swept = 0;
    for (final entry in _bestCoins.entries) {
      final total = _coinTotals[entry.key];
      if (total != null && total > 0 && entry.value >= total) swept++;
    }
    return swept;
  }

  /// Which local day [when] falls on, counted from the epoch.
  ///
  /// Built from the calendar fields rather than by dividing a timestamp, so a
  /// day is a real local day: one that daylight saving made 23 hours long is
  /// still one day, and the boundary is the player's midnight.
  static int dayIndex(DateTime when) =>
      DateTime(when.year, when.month, when.day)
          .difference(DateTime(1970))
          .inDays;

  /// Days played in a row, or 0 once a day has been missed.
  ///
  /// Yesterday still counts as alive. A player who played yesterday and has
  /// not opened the game yet today is mid streak, not broken — showing 0 all
  /// morning would tell them they had lost something they still have. The
  /// streak only reads 0 once a whole day has gone by without a run.
  int streakOn(DateTime now) {
    final last = _lastPlayedDay;
    if (last == null) return 0;
    final today = dayIndex(now);
    return last >= today - 1 ? _streak : 0;
  }

  int get streak => streakOn(DateTime.now());

  /// Counts today towards the streak. Called when a level is opened.
  ///
  /// "Played" is starting a level rather than finishing one, deliberately. A
  /// player stuck on a hard level can spend an evening on it and clear
  /// nothing, and taking their streak for that would punish them for the one
  /// thing the game is asking them to do.
  Future<void> notePlayed({DateTime? now}) async {
    final today = dayIndex(now ?? DateTime.now());
    final last = _lastPlayedDay;
    if (last == today) return;

    // Yesterday carries on; anything older starts again at today. Not zero:
    // they are playing, and a run that leaves the counter empty would read as
    // not having counted.
    _streak = last == today - 1 ? _streak + 1 : 1;
    _lastPlayedDay = today;
    notifyListeners();

    await _prefs?.setInt(_streakKey, _streak);
    await _prefs?.setInt(_streakDayKey, today);
  }

  /// How many times a level has been lost, all time.
  int deathsFor(int levelId) => _deaths[levelId] ?? 0;

  /// Records a lost life. Cheap and frequent, so it writes through without
  /// notifying: nothing on screen is drawn from it.
  Future<void> recordDeath(int levelId) async {
    final next = deathsFor(levelId) + 1;
    _deaths[levelId] = next;
    await _prefs?.setInt('$_deathsPrefix$levelId', next);
  }

  /// Records a finish, keeping the best star count and the fastest time. The
  /// two are tracked separately: a slow clean run keeps its 3 stars, a fast
  /// scrappy one keeps its time.
  Future<void> record(
    int levelId,
    int stars,
    double seconds, {
    int coins = 0,
    int coinsOnLevel = 0,
  }) async {
    // Remembered so [sweptCount] can tell a swept level from a nearly swept
    // one without reloading the pack to ask how many coins it held.
    if (coinsOnLevel > 0 && _coinTotals[levelId] != coinsOnLevel) {
      _coinTotals[levelId] = coinsOnLevel;
      await _prefs?.setInt('$_coinTotalPrefix$levelId', coinsOnLevel);
    }

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

  /// Moves a pad. The spot is a fraction of the screen, not a point.
  Future<void> setPadSpot(ControlPad pad, Offset spot) async {
    if (_padSpots[pad] == spot) return;
    _padSpots[pad] = spot;
    notifyListeners();
    await _prefs?.setDouble('$_padPrefix${pad.name}.x', spot.dx);
    await _prefs?.setDouble('$_padPrefix${pad.name}.y', spot.dy);
  }

  /// Resizes a pad, as a multiple of its standard diameter.
  Future<void> setPadScale(ControlPad pad, double scale) async {
    final level = scale.clamp(kMinPadScale, kMaxPadScale);
    if (padScale(pad) == level) return;
    _padScales[pad] = level;
    notifyListeners();
    await _prefs?.setDouble('$_padPrefix${pad.name}.s', level);
  }

  /// Puts all three pads back where they started, at the size they started.
  Future<void> resetPadLayout() async {
    if (!padsMoved) return;
    _padSpots.clear();
    _padScales.clear();
    notifyListeners();
    for (final pad in ControlPad.values) {
      await _prefs?.remove('$_padPrefix${pad.name}.x');
      await _prefs?.remove('$_padPrefix${pad.name}.y');
      await _prefs?.remove('$_padPrefix${pad.name}.s');
    }
  }

  /// Everything worth carrying to another device, as plain JSON.
  ///
  /// Only levels that have actually been played appear, so a player on level 40
  /// uploads a few hundred bytes rather than a file with ten thousand empty
  /// entries in it.
  ///
  /// The settings are deliberately left out. How loud a phone is, whether it
  /// uses halves or buttons, and where the pads have been dragged to, are
  /// facts about that phone rather than about the player — carrying them
  /// across would change a device's controls out from under somebody who never
  /// asked for that. The pad layout is the clearest case of the three: one
  /// arranged for a tablet's thumbs is the right answer on the device it was
  /// made on and the wrong one everywhere else.
  Map<String, dynamic> toSnapshot() => {
        'v': 1,
        'stars': {for (final e in _stars.entries) '${e.key}': e.value},
        'best': {for (final e in _bestSeconds.entries) '${e.key}': e.value},
        'coins': {for (final e in _bestCoins.entries) '${e.key}': e.value},
        'coinsOf': {for (final e in _coinTotals.entries) '${e.key}': e.value},
        'deaths': {for (final e in _deaths.entries) '${e.key}': e.value},
        'streak': _streak,
        if (_lastPlayedDay != null) 'streakDay': _lastPlayedDay,
      };

  /// Folds a snapshot from another device into this one, keeping whichever
  /// side is better for every single value.
  ///
  /// Merging rather than choosing is the whole design. "Newest wins" is what
  /// makes a player lose an evening's play because they opened the game on a
  /// tablet, and almost everything here is a personal best, so there is no
  /// genuine conflict to resolve: more stars, fewer seconds and more coins are
  /// all unambiguously better.
  ///
  /// **Every rule below is idempotent**, which matters more than it looks:
  /// merging twice has to give the same answer as merging once, because a
  /// device can and will sync the same save repeatedly. That is why deaths
  /// take the larger count rather than the sum. Adding would double on the
  /// second merge, then double again, and hand out [Ach.stubborn] to somebody
  /// who never earned it.
  Future<void> mergeSnapshot(Map<String, dynamic> snapshot) async {
    Map<int, num> read(String key) {
      final raw = snapshot[key];
      if (raw is! Map) return const {};
      final out = <int, num>{};
      for (final entry in raw.entries) {
        final id = int.tryParse('${entry.key}');
        final value = entry.value;
        if (id != null && value is num) out[id] = value;
      }
      return out;
    }

    for (final e in read('stars').entries) {
      if (e.value.toInt() > starsFor(e.key)) _stars[e.key] = e.value.toInt();
    }
    for (final e in read('best').entries) {
      final mine = _bestSeconds[e.key];
      if (mine == null || e.value < mine) _bestSeconds[e.key] = e.value * 1.0;
    }
    for (final e in read('coins').entries) {
      if (e.value.toInt() > bestCoinsFor(e.key)) {
        _bestCoins[e.key] = e.value.toInt();
      }
    }
    for (final e in read('coinsOf').entries) {
      // How many coins a level holds is a fact about the level, so the two
      // sides can only disagree if one of them is stale.
      if (e.value.toInt() > (_coinTotals[e.key] ?? 0)) {
        _coinTotals[e.key] = e.value.toInt();
      }
    }
    for (final e in read('deaths').entries) {
      if (e.value.toInt() > deathsFor(e.key)) _deaths[e.key] = e.value.toInt();
    }

    final theirStreak = (snapshot['streak'] as num?)?.toInt() ?? 0;
    if (theirStreak > _streak) {
      _streak = theirStreak;
      // Taken together with the streak it belongs to. A long streak with the
      // wrong day attached would be read as broken and shown as zero.
      final day = (snapshot['streakDay'] as num?)?.toInt();
      if (day != null) _lastPlayedDay = day;
    }

    notifyListeners();
    await _writeAll();
  }

  /// Writes the whole of progress back to disk. Only used after a merge, which
  /// can touch any number of levels at once.
  Future<void> _writeAll() async {
    final prefs = _prefs;
    if (prefs == null) return;
    for (final e in _stars.entries) {
      await prefs.setInt('$_starsPrefix${e.key}', e.value);
    }
    for (final e in _bestSeconds.entries) {
      await prefs.setDouble('$_bestPrefix${e.key}', e.value);
    }
    for (final e in _bestCoins.entries) {
      await prefs.setInt('$_coinsPrefix${e.key}', e.value);
    }
    for (final e in _coinTotals.entries) {
      await prefs.setInt('$_coinTotalPrefix${e.key}', e.value);
    }
    for (final e in _deaths.entries) {
      await prefs.setInt('$_deathsPrefix${e.key}', e.value);
    }
    await prefs.setInt(_streakKey, _streak);
    final day = _lastPlayedDay;
    if (day != null) await prefs.setInt(_streakDayKey, day);
  }

  Future<void> resetProgress() async {
    final ids = {
      ..._stars.keys,
      ..._bestSeconds.keys,
      ..._bestCoins.keys,
      ..._coinTotals.keys,
      ..._deaths.keys,
    };
    _stars.clear();
    _bestSeconds.clear();
    _bestCoins.clear();
    _coinTotals.clear();
    _deaths.clear();
    _streak = 0;
    _lastPlayedDay = null;
    notifyListeners();

    await _prefs?.remove(_streakKey);
    await _prefs?.remove(_streakDayKey);
    for (final id in ids) {
      await _prefs?.remove('$_starsPrefix$id');
      await _prefs?.remove('$_bestPrefix$id');
      await _prefs?.remove('$_coinsPrefix$id');
      await _prefs?.remove('$_coinTotalPrefix$id');
      await _prefs?.remove('$_deathsPrefix$id');
    }
  }
}

final ProgressStore progressStore = ProgressStore();

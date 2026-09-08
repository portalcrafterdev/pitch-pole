/// What part of the pack a level belongs to, so a menu can name where you are.
///
/// Ten thousand levels in one flat list is a number, not a place. A chapter and
/// a band give the player something to hold on to: "chapter 4 of the ramp"
/// says more than "level 187".
///
/// The two boundaries are section 8's — 1 to 5 taught, 6 to 300 the ramp,
/// everything past that the long climb. They are written out here rather than
/// imported because the generator that owns them is authoring time only and is
/// deliberately not part of the shipped app.
library;

/// Levels per chapter. Fifty is two full rows of the level grid on a phone,
/// which makes a chapter something you can actually see the end of.
const int kChapterSize = 50;

const int _taughtEnd = 5;
const int _rampEnd = 300;

int chapterFor(int levelId) => ((levelId - 1) ~/ kChapterSize) + 1;

/// The first and last level of the chapter [levelId] falls in.
(int, int) chapterRange(int levelId) {
  final start = (chapterFor(levelId) - 1) * kChapterSize + 1;
  return (start, start + kChapterSize - 1);
}

String bandFor(int levelId) {
  if (levelId <= _taughtEnd) return 'TAUGHT';
  if (levelId <= _rampEnd) return 'THE RAMP';
  return 'THE LONG CLIMB';
}

/// "CHAPTER 4 · THE RAMP", for a line under a button or across a header.
String chapterLabelFor(int levelId) =>
    'CHAPTER ${chapterFor(levelId)} · ${bandFor(levelId)}';

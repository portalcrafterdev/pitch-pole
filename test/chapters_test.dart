import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/game/logic/level_pack.dart';
import 'package:pitchpole/ui/chapters.dart';

void main() {
  group('which chapter a level is in', () {
    test('the first chapter starts at one, not zero', () {
      expect(chapterFor(1), 1);
      expect(chapterFor(kChapterSize), 1);
      expect(chapterFor(kChapterSize + 1), 2);
    });

    test('a chapter covers exactly kChapterSize levels', () {
      for (final id in [1, 50, 51, 137, 999, kTotalLevels]) {
        final (first, last) = chapterRange(id);
        expect(last - first + 1, kChapterSize);
        expect(id, greaterThanOrEqualTo(first));
        expect(id, lessThanOrEqualTo(last));
      }
    });

    test('every level in the pack lands in a chapter, and the last one is '
        'reachable by stepping', () {
      // The level select steps a chapter at a time and clamps at
      // chapterFor(count). If that came out short, the back of the pack would
      // be unreachable by anything but a scroll.
      final last = chapterFor(kTotalLevels);
      final (first, _) = chapterRange(kTotalLevels);
      expect(first, lessThanOrEqualTo(kTotalLevels));
      expect((last - 1) * kChapterSize + 1, lessThanOrEqualTo(kTotalLevels));
      expect(last * kChapterSize, greaterThanOrEqualTo(kTotalLevels));
    });
  });

  group('what a level is called', () {
    test('the bands match section 8', () {
      // 1 to 5 taught, 6 to 300 the ramp, everything past that the long climb.
      expect(bandFor(1), 'TAUGHT');
      expect(bandFor(5), 'TAUGHT');
      expect(bandFor(6), 'THE RAMP');
      expect(bandFor(300), 'THE RAMP');
      expect(bandFor(301), 'THE LONG CLIMB');
      expect(bandFor(kTotalLevels), 'THE LONG CLIMB');
    });

    test('the label names both the chapter and the band', () {
      expect(chapterLabelFor(1), 'CHAPTER 1 · TAUGHT');
      expect(chapterLabelFor(301), 'CHAPTER 7 · THE LONG CLIMB');
    });
  });
}

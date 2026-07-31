import 'package:flutter/material.dart';

import '../../data/level_repository.dart';
import '../../data/progress_store.dart';
import '../../game/logic/level_model.dart';
import '../palette.dart';
import '../widgets/star_row.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.background,
      appBar: AppBar(
        backgroundColor: Palette.background,
        elevation: 0,
        foregroundColor: Palette.text,
        title: const Text(
          'LEVELS',
          style: TextStyle(
            fontSize: 15,
            letterSpacing: 4,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          AnimatedBuilder(
            animation: progressStore,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded,
                      size: 18, color: Palette.star),
                  const SizedBox(width: 6),
                  Text(
                    '${progressStore.totalStars}',
                    style: const TextStyle(
                      color: Palette.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<LevelModel>>(
        future: levelRepository.loadAll(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Palette.textMuted),
            );
          }
          final levels = snapshot.data!;
          return AnimatedBuilder(
            animation: progressStore,
            builder: (context, _) => GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 108,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              itemCount: levels.length,
              itemBuilder: (context, index) => _LevelTile(
                level: levels[index],
                stars: progressStore.starsFor(levels[index].id),
                bestSeconds: progressStore.bestSecondsFor(levels[index].id),
                unlocked: progressStore.isUnlocked(levels[index].id),
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => GameScreen(levels: levels, index: index),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.stars,
    required this.bestSeconds,
    required this.unlocked,
    required this.onTap,
  });

  final LevelModel level;
  final int stars;
  final double? bestSeconds;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final solved = stars > 0;
    return Material(
      color: unlocked ? Palette.surface : Palette.surface.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: unlocked ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: solved
                  ? Palette.door.withValues(alpha: 0.35)
                  : Palette.text.withValues(alpha: unlocked ? 0.1 : 0.04),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!unlocked)
                Icon(
                  Icons.lock_rounded,
                  size: 22,
                  color: Palette.textMuted.withValues(alpha: 0.5),
                )
              else
                Text(
                  '${level.id}',
                  style: TextStyle(
                    color: solved ? Palette.door : Palette.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(height: 6),
              if (unlocked)
                StarRow(stars: stars, size: 15)
              else
                const SizedBox(height: 15),
              const SizedBox(height: 3),
              Text(
                bestSeconds == null ? ' ' : '${bestSeconds!.toStringAsFixed(1)}s',
                style: const TextStyle(
                  color: Palette.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

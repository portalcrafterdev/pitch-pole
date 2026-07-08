/// The character's state during one run. Pure Dart.
library;

import 'physics.dart';

const int kStartingLives = 3;

enum RunStatus { running, dead, won }

/// The two things the player can do, plus doing nothing.
///
/// Up and Down are absolute, not a toggle: pressing Up while already on the
/// ceiling does nothing. A toggle causes accidental deaths.
enum RunInput { none, flipUp, flipDown, jump }

class RunState {
  RunState({
    this.x = 0,
    double? y,
    this.vy = 0,
    this.gravityUp = false,
    this.grounded = true,
    this.lives = kStartingLives,
    this.status = RunStatus.running,
    this.elapsed = 0,
    this.checkpointX = 0,
  }) : y = y ?? restingY(gravityUp: gravityUp);

  /// World position of the character's left edge. Starts at 0.
  double x;

  /// World position of the character's top edge.
  double y;

  /// Vertical velocity. Positive is downwards.
  double vy;

  bool gravityUp;
  bool grounded;

  int lives;
  RunStatus status;

  /// Real time spent on this attempt, across deaths. Drives the HUD clock and
  /// the recorded best time.
  double elapsed;

  /// Where the character respawns after a death.
  double checkpointX;

  bool get isRunning => status == RunStatus.running;

  /// Level time at the current position. Because forward speed is constant,
  /// this is a pure function of [x], which is what keeps hopper phases
  /// identical every time the player reaches the same spot.
  double levelTimeAt(double runSpeed) => x / runSpeed;

  Box get box => playerBox(x, y);

  RunState copy() => RunState(
        x: x,
        y: y,
        vy: vy,
        gravityUp: gravityUp,
        grounded: grounded,
        lives: lives,
        status: status,
        elapsed: elapsed,
        checkpointX: checkpointX,
      );

  @override
  String toString() => 'RunState(x: ${x.toStringAsFixed(1)}, '
      'y: ${y.toStringAsFixed(1)}, vy: ${vy.toStringAsFixed(1)}, '
      'gravityUp: $gravityUp, grounded: $grounded, lives: $lives, '
      'status: ${status.name})';
}

import 'package:flutter/material.dart';

import '../../data/achievements.dart';
import '../../data/games_auth.dart';
import '../../data/leaderboards.dart';
import '../../data/menu_audio.dart';
import '../menu_palette.dart';
import '../palette.dart';

/// The Play Games / Game Center button on the home screen.
///
/// Three states in one control: signed out offers to sign in, signing in is
/// busy and cannot be tapped twice, and signed in shows who. It is never a
/// gate — the game plays identically without it — so it is styled as a quiet
/// secondary action, below the two that matter.
class SignInButton extends StatelessWidget {
  const SignInButton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: gamesAuth,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final signedIn = gamesAuth.isSignedIn;
    // Sits on the bright sky of the home screen rather than on a dark panel,
    // so it is a white pill with dark text. Quiet here means less colour, not
    // less contrast: it is still the third thing read on the page.
    final accent = signedIn ? MenuPalette.play : MenuPalette.inkSoft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: compact ? 40 : 46,
          child: Material(
            color: Colors.white.withValues(alpha: signedIn ? 0.92 : 0.78),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: gamesAuth.isBusy
                  ? null
                  : () {
                      MenuAudio.instance.tap();
                      signedIn ? _showAccount(context) : _signIn(context);
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: accent.withValues(alpha: signedIn ? 0.85 : 0.35),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Badge(accent: accent),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _label(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: signedIn ? MenuPalette.play : MenuPalette.ink,
                          fontSize: 12,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (gamesAuth.lastError != null) ...[
          const SizedBox(height: 6),
          Text(
            gamesAuth.lastError!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MenuPalette.ink,
              fontSize: 10,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  String _label() {
    switch (gamesAuth.state) {
      case GamesAuthState.signingIn:
        return 'SIGNING IN…';
      case GamesAuthState.signedIn:
        return gamesAuth.playerName?.toUpperCase() ?? 'SIGNED IN';
      case GamesAuthState.signedOut:
        return 'SIGN IN WITH ${gamesAuth.service.short.toUpperCase()}';
    }
  }

  Future<void> _signIn(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await gamesAuth.signIn();
    if (!context.mounted) return;

    if (ok) {
      messenger?.showSnackBar(
        SnackBar(
          backgroundColor: Palette.surface,
          content: Text(
            'Signed in as ${gamesAuth.playerName}',
            style: const TextStyle(color: Palette.text),
          ),
        ),
      );
      return;
    }

    // A failure has to be said out loud rather than left as a line of small
    // text under the button. The platform puts its own full screen sheet over
    // the game to sign in, and when that sheet closes by itself with nothing
    // signed in, the player is looking at the menu again with no idea whether
    // anything happened at all.
    _showFailure(context);
  }

  void _showFailure(BuildContext context) {
    final detail = gamesAuth.lastErrorDetail;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Palette.surface,
        title: Text(
          gamesAuth.lastError ?? 'Could not sign in',
          style: const TextStyle(color: Palette.text, fontSize: 17),
        ),
        content: detail == null
            ? null
            : SingleChildScrollView(
                child: Text(
                  detail,
                  style: const TextStyle(
                    color: Palette.textMuted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK', style: TextStyle(color: Palette.door)),
          ),
        ],
      ),
    );
  }

  void _showAccount(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.surface,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: const _Badge(accent: Palette.door, size: 22),
                title: Text(
                  gamesAuth.playerName ?? 'Signed in',
                  style: const TextStyle(
                    color: Palette.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Signed in to ${gamesAuth.service.long}',
                  style: const TextStyle(
                    color: Palette.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
              const Divider(height: 24, indent: 16, endIndent: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Stars, times and coins are saved on this device either '
                  'way. Signing in does not move them and does not change '
                  'anything in a run.',
                  style: TextStyle(
                    color: Palette.textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Both open the platform's own screen. The game draws neither:
              // Play and Game Center already render the boards and the
              // achievement list, and a copy inside the game would be a second
              // thing to keep true. They live here rather than on the home
              // screen because there is nothing behind them signed out.
              ListTile(
                leading: const Icon(Icons.leaderboard_rounded,
                    color: Palette.door),
                title: const Text('Leaderboards',
                    style: TextStyle(color: Palette.text)),
                subtitle: const Text(
                  'Levels, stars, coins and levels swept.',
                  style: TextStyle(color: Palette.textMuted, fontSize: 12),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  leaderboards.show();
                },
              ),
              ListTile(
                leading: const Icon(Icons.emoji_events_rounded,
                    color: Palette.hopper),
                title: const Text('Achievements',
                    style: TextStyle(color: Palette.text)),
                subtitle: const Text(
                  'Earned whether you are signed in or not.',
                  style: TextStyle(color: Palette.textMuted, fontSize: 12),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  achievements.show();
                },
              ),
              const Divider(height: 24, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.link_off_rounded,
                    color: Palette.bolted),
                title: const Text('Forget this account',
                    style: TextStyle(color: Palette.bolted)),
                // Neither service lets a game sign an account out of the
                // device, so promising a sign out would be a lie.
                subtitle: Text(
                  'Stops the game reconnecting. To sign the account out of '
                  'the device, use the ${gamesAuth.service.short} app.',
                  style: const TextStyle(
                    color: Palette.textMuted,
                    fontSize: 12,
                  ),
                ),
                isThreeLine: true,
                onTap: () async {
                  await gamesAuth.forget();
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// The avatar when the platform gave one, a spinner while signing in, and a
/// controller otherwise.
class _Badge extends StatelessWidget {
  const _Badge({required this.accent, this.size = 18});

  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (gamesAuth.isBusy) {
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(strokeWidth: 2, color: accent),
      );
    }

    final icon = gamesAuth.playerIcon;
    if (gamesAuth.isSignedIn && icon != null) {
      return ClipOval(
        child: Image.memory(
          icon,
          width: size,
          height: size,
          fit: BoxFit.cover,
          // A broken avatar must not take the button down with it.
          errorBuilder: (_, _, _) =>
              Icon(Icons.sports_esports_rounded, size: size, color: accent),
        ),
      );
    }

    return Icon(
      gamesAuth.isSignedIn
          ? Icons.check_circle_rounded
          : Icons.sports_esports_rounded,
      size: size,
      color: accent,
    );
  }
}

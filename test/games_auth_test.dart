import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/data/games_auth.dart';
import 'package:pitchpole/data/level_repository.dart';
import 'package:pitchpole/data/progress_store.dart';
import 'package:pitchpole/main.dart';
import 'package:pitchpole/ui/widgets/sign_in_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Play Games and Game Center are platform services with no test double, so
/// every call here lands on a method channel nothing is listening to. That is
/// the point: what is being checked is that the game survives it, because a
/// debug build on a phone with no console project set up behaves the same way.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await progressStore.load();
    // The store is a singleton shared across tests, so wipe the account
    // between them rather than letting one test's state reach the next.
    await gamesAuth.forget();
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('signing in', () {
    test('a fresh install starts signed out and never asks', () async {
      await gamesAuth.load();

      expect(gamesAuth.isSignedIn, isFalse);
      expect(gamesAuth.optedIn, isFalse,
          reason: 'nothing may reach the platform until the player asks');
      expect(gamesAuth.lastError, isNull,
          reason: 'not being signed in is not an error to report');
    });

    test('a failed sign in leaves the player signed out with a reason',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await gamesAuth.load();

      expect(await gamesAuth.signIn(), isFalse);
      expect(gamesAuth.isSignedIn, isFalse);
      expect(gamesAuth.isBusy, isFalse, reason: 'it must not stay spinning');
      expect(gamesAuth.lastError, isNotNull);
    });

    test('an unsupported platform says so rather than throwing', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await gamesAuth.load();

      expect(gamesAuth.isSupported, isFalse);
      expect(await gamesAuth.signIn(), isFalse);
      expect(gamesAuth.lastError, contains('phone'));
    });

    test('a signed in account is remembered across a restart', () async {
      SharedPreferences.setMockInitialValues({
        'games.optedIn': true,
        'games.playerName': 'Bramble',
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      await gamesAuth.load();

      // Shown straight away from the cache. The platform round trip is what
      // would confirm or demote it, and on this platform there is none.
      expect(gamesAuth.playerName, 'Bramble');
      expect(gamesAuth.isSignedIn, isTrue);
    });

    test('forgetting the account stops it reconnecting', () async {
      SharedPreferences.setMockInitialValues({
        'games.optedIn': true,
        'games.playerName': 'Bramble',
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await gamesAuth.load();

      await gamesAuth.forget();
      expect(gamesAuth.isSignedIn, isFalse);
      expect(gamesAuth.optedIn, isFalse);

      await gamesAuth.load();
      expect(gamesAuth.playerName, isNull,
          reason: 'a forgotten account must not come back on the next launch');
    });

    test('the service is named after the platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(gamesAuth.service, GamesService.playGames);
      expect(gamesAuth.isSupported, isTrue);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(gamesAuth.service, GamesService.gameCenter);
      expect(gamesAuth.isSupported, isTrue);
    });
  });

  group('the button on the home screen', () {
    /// The platform override has to be back to null before the test body
    /// returns: the test framework checks the foundation debug variables
    /// itself, and it does so before any tearDown runs.
    void homeTest(
      String name,
      TargetPlatform platform,
      Future<void> Function(WidgetTester tester) body,
    ) {
      testWidgets(name, (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          await tester.runAsync(() => levelRepository.loadAll());
          await tester.pumpWidget(const PitchpoleApp());
          await tester.pumpAndSettle();
          await body(tester);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    homeTest('names the platform service when signed out',
        TargetPlatform.android, (tester) async {
      expect(find.byType(SignInButton), findsOneWidget);
      expect(find.text('SIGN IN WITH PLAY GAMES'), findsOneWidget);
    });

    homeTest('says Game Center on iOS', TargetPlatform.iOS, (tester) async {
      expect(find.text('SIGN IN WITH GAME CENTER'), findsOneWidget);
    });

    homeTest('shows the player instead once signed in', TargetPlatform.android,
        (tester) async {
      gamesAuth.debugSetSignedIn('Bramble');
      await tester.pumpAndSettle();

      expect(find.text('BRAMBLE'), findsOneWidget);
      expect(find.text('SIGN IN WITH PLAY GAMES'), findsNothing);
    });

    homeTest('a failed tap says so out loud and stays tappable',
        TargetPlatform.android, (tester) async {
      await tester.tap(find.text('SIGN IN WITH PLAY GAMES'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'a platform with no Play Games project must not crash the '
              'menu');

      // The whole point of the dialog: the platform draws its own full screen
      // sheet over the game, and when that closes with nothing signed in, a
      // line of small text under a button is not enough to explain why.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(gamesAuth.lastErrorDetail, isNotNull);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(gamesAuth.lastError, isNotNull, reason: 'and it stays on screen');
      expect(find.text('SIGN IN WITH PLAY GAMES'), findsOneWidget);
    });

    homeTest('play and levels still work signed out', TargetPlatform.android,
        (tester) async {
      // The point of the whole feature being optional: nothing is gated.
      expect(find.text('PLAY'), findsOneWidget);
      expect(find.text('LEVELS'), findsOneWidget);
    });
  });
}

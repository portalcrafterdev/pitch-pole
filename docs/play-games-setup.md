# Turning on Google Play Games sign in

Everything in the app is already wired. The only thing missing is a Play Games
Services project, which lives in the Play Console and cannot be created from
the codebase. This is that job, start to finish.

Until step 5 is done the button on the home screen still appears and the game
plays normally. Tapping it reports that Play Games is not set up rather than
pretending to work, so it is safe to ship in this state.

Apple Game Center is deliberately not covered here. The code already handles
it and picks the right service per platform, but the console side is on hold.

## What is already done

| Piece | Where | State |
| --- | --- | --- |
| Sign in, restore, forget, error reporting | [lib/data/games_auth.dart](../lib/data/games_auth.dart) | done |
| `com.google.android.gms.games.APP_ID` meta-data | [AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml) | done |
| `INTERNET` permission in every build | [AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml) | done |
| Permanent `applicationId` | [build.gradle.kts](../android/app/build.gradle.kts) | `com.portalcrafter.pitchpole` |
| Play Games project number | [game_ids.xml](../android/app/src/main/res/values/game_ids.xml) | **placeholder `000000000000`** |

## 1. Create the Play Games Services project

Play Console, your app, then **Grow players > Play Games Services > Setup and
management > Configuration**.

Choose **"No, my game doesn't use Google APIs"** unless you already have a
Google Cloud project for this game, and give it a name. Saving it produces a
**project number**: twelve digits, something like `123456789012`. That number
is what step 5 needs.

## 2. Add an Android credential

Same screen, **Credentials > Add credential > Android**.

It asks for the package name and a signing certificate SHA-1. The package name
is `com.portalcrafter.pitchpole` and must match exactly, because Play Games
matches on the package name and certificate together.

## 3. Get the SHA-1

Debug and release builds are signed with different certificates, and Play Games
treats them as different apps. Each one needs its own credential or sign in
works in one and fails in the other.

For the debug build on this machine:

```bash
keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android | grep SHA1
```

On this machine that is:

```
58:59:5B:4C:80:AF:98:F6:EF:4E:52:21:A0:41:43:F4:C6:DF:CB:AF
```

Every machine generates its own debug keystore, so a second developer needs a
credential for theirs too.

For a release build, note that `android/app/build.gradle.kts` currently signs
release with the **debug** keystore, so today the fingerprint above covers both.
When a real release keystore is added, that certificate needs its own
credential. If the app ships through Play App Signing, use the SHA-1 Google
shows under **Setup > App integrity > App signing key certificate**, not the
local one: Google re-signs the upload.

## 4. Add yourself as a tester

**Play Games Services > Setup and management > Testers.**

This is the step that is easiest to miss and produces the most confusing
failure. Until the Play Games Services project is published, sign in fails for
any account not on that list, even when everything else is correct, and it
fails the same way an unconfigured project does.

Add the Google account that is signed in on the phone or emulator you test on.

## 5. Put the number in the app

Replace the placeholder in
[game_ids.xml](../android/app/src/main/res/values/game_ids.xml):

```xml
<string name="games_app_id" translatable="false">123456789012</string>
```

Then rebuild. This value is read out of the manifest by the Play Games SDK when
the process starts, so a hot reload will not pick it up.

## Checking it worked

Run on a device or emulator that has Google Play Services **and a Google
account signed in**, then tap the button on the home screen.

The emulator this was tested on had Play Services but no account, so Play Games
opened Google's "add an account" flow instead of an account picker. That is
what a missing account looks like, not a bug in the game.

Expected: an account chooser, then the button changes to the player's name.

## When it fails

The game reports failures rather than swallowing them. Tapping the button and
getting a dialog is the normal way to find out what is wrong.

- **"Play Games is not set up for this build."** No project registered for this
  package name and certificate. Steps 1 to 3, or step 4: a missing tester looks
  identical from inside the game.
- **"Sign in was not finished."** The Play Games screen closed without signing
  in, usually because it was dismissed. Nothing is wrong.
- **"Play Games is not available in this build."** The platform side is
  missing, which normally means it is running somewhere it does not ship.

A crash on launch rather than a failed sign in means `games_app_id` is missing
entirely. The SDK reads it from a `ContentProvider` at process start, so it
must be present even while it is a placeholder.

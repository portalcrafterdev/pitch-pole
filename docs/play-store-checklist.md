# Publishing Pitchpole to Google Play

What the store listing needs, what the console will ask, and what is not ready
yet. The listing copy and the artwork live in [store/](../store/).

Read the blockers first. Two of them stop a release build being publishable at
all, and one is a policy question that has to be answered before the listing is
filled in, not after.

---

## Blockers

### 1. The release build is signed with the debug keystore

[android/app/build.gradle.kts](../android/app/build.gradle.kts) says so in as
many words:

```kotlin
release {
    // TODO: Add your own signing config for the release build.
    signingConfig = signingConfigs.getByName("debug")
}
```

Play will not accept an upload signed with the Android debug key, and the debug
key is shared by every SDK install, so anyone could sign an update to this app.
Generate an upload keystore, keep it out of the repository, and point the
release build at it.

**This also breaks Play Games sign in on release builds.** Play Games matches on
the package name and the signing certificate together, so a new certificate
needs a new Android credential in the Play Games Services project. With Play App
Signing, Google re-signs the upload, and the fingerprint that matters is the one
under **Setup > App integrity > App signing key certificate**, not the local
one. See [play-games-setup.md](play-games-setup.md).

### 2. There is no privacy policy

Required for every app, and doubly so here: AdMob collects the Advertising ID.
It must be a public URL, reachable without a login, and it has to actually
describe what the app collects. The console rejects a link that 404s.

What this app does, for whoever writes it: it stores stars, best times, coins
and settings on the device with `shared_preferences` and sends none of it
anywhere. There is no backend and no account system of its own. Google Play
Games sign in is optional and yields a display name and avatar, used only to
show who is signed in. Google AdMob serves the ads and collects what AdMob
collects.

### 3. Ship an app bundle, not an APK

```bash
flutter build appbundle --release
```

Play has required AAB for new apps since 2021. The `flutter build apk` output is
for sideloading and CI, not for the store.

---

## The kids question, which decides several answers at once

The app was deliberately redesigned to be kid friendly, so the console's
**Target audience and content** section is not a formality. Answering it to
include under 13s puts the app in the Families programme, and that has teeth:

- **Ads must come from a Families self-certified SDK.** AdMob qualifies, but
  only when it is configured for it.
- **Ad content must be rated G**, and personalised advertising to children is
  not allowed.
- **Ad placement is restricted.** Worth reviewing: an interstitial currently
  fires on pressing PLAY, before the first level of a fresh install is reached,
  and `showAtBreak` in [lib/data/ads.dart](../lib/data/ads.dart) has no
  frequency cap, so one can appear at every level break.

**The app does not configure any of this today.** There is no
`RequestConfiguration` anywhere in the codebase. If the answer is "yes,
children", this has to go in before the first release, at start up, before any
ad loads:

```dart
await MobileAds.instance.updateRequestConfiguration(
  RequestConfiguration(
    tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
    tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes,
    maxAdContentRating: MaxAdContentRating.g,
  ),
);
```

`maxAdContentRating: g` is worth setting either way: it costs little and no
kid-facing game wants a mature ad in it. The two `tagFor...` flags are the ones
tied to the declaration, and they reduce ad revenue, so they are a decision
rather than a default. Set them to match what you tell the console: saying one
thing in the console and another in the code is the version that gets the app
pulled.

---

## Console sections

| Section | Answer |
| --- | --- |
| App or game | Game |
| Category | Arcade |
| Free or paid | Free |
| Contains ads | **Yes** (banner, interstitial, rewarded) |
| In-app purchases | No |
| Content rating | Complete the IARC questionnaire. Cartoon characters, no blood, no gore, no text chat, no user content, no gambling. Expect PEGI 3 / ESRB Everyone. |
| Data safety | See below |
| Target audience | See the kids question above |
| Government app | No |
| Financial features | None |
| Health | No |

### Data safety

The app itself collects nothing. AdMob does, and the form is about the app as
shipped, so the SDK's collection is yours to declare.

| Data type | Collected | Why |
| --- | --- | --- |
| Device or other IDs | Yes | Advertising ID, by AdMob |
| App activity / interactions | Yes | Ad interactions, by AdMob |
| Approximate location | Check AdMob's guidance | AdMob may derive coarse location from IP |
| Personal info, files, photos, contacts, messages | No | nothing in the app touches them |

Answer "data is encrypted in transit" (AdMob uses HTTPS). Google publishes a
data-safety mapping for the Mobile Ads SDK; use it rather than guessing, since
the answers change with SDK versions.

Play Games sign in returns a display name and avatar. It is optional and the
game stores the name locally only, but declare it if you keep it.

---

## Store listing assets

All present in [store/](../store/). Copy to paste is in
[store/listing.md](../store/listing.md).

| Asset | Requirement | Status |
| --- | --- | --- |
| App name | 30 chars | `Pitchpole` |
| Short description | 80 chars | 73 chars |
| Full description | 4000 chars | about 1900 |
| App icon | 512 x 512 PNG, under 1 MB | `store/icon-512.png`, 24 KB |
| Feature graphic | 1024 x 500, no transparency | `store/feature-graphic.jpg`. The PNG is RGBA and fully opaque, so use the JPEG if the console objects |
| Phone screenshots | 2 to 8, 16:9, 320 to 3840 px | four at 1920 x 1080 |
| Tablet screenshots | optional | **none**, so the game will be flagged as not optimised for large screens |

Regenerate the icon and banner with:

```bash
flutter test tool/make_store_art.dart
```

---

## Technical checks before uploading

- **Version.** `pubspec.yaml` is at `1.0.0+1`. The `+1` is the versionCode, and
  every upload needs a higher one than the last.
- **Target API level.** Flutter 3.44 targets API 36, comfortably inside Play's
  current requirement.
- **The description in `pubspec.yaml`** still says "A new Flutter project."
  Nobody sees it on the listing, but it is in the generated Dart docs.
- **Real ad units in release.** [lib/data/ads.dart](../lib/data/ads.dart)
  switches on `kDebugMode`, so debug uses Google's test units and release uses
  the real ones. Do not test a release build by tapping your own ads: Google
  counts a developer's own clicks as invalid traffic, and that is the usual way
  an AdMob account gets suspended.
- **AdMob app id** is real and in the manifest already, in
  [ad_ids.xml](../android/app/src/main/res/values/ad_ids.xml).
- **iOS** needs its own AdMob app and its own app id in `Info.plist` before it
  ships, rather than a copy of the Android one.

---

## Order of work

1. Upload keystore, release signing config, Play App Signing.
2. Update the Play Games credential with the new certificate.
3. Answer the target audience question, then configure the ads SDK to match.
4. Write and host the privacy policy.
5. Fill in the listing from [store/listing.md](../store/listing.md) and upload
   the artwork.
6. Content rating and data safety forms.
7. `flutter build appbundle --release`, upload to internal testing, install it
   from Play on a real phone, and check that Play Games sign in works with the
   release certificate before promoting it.

# Data safety answers

[data-safety.csv](data-safety.csv) is Play's bulk-import CSV, filled for
Pitchpole. Upload it in the Play Console under **App content > Data safety >
Import from CSV**, then read the summary screen it produces before submitting.
It is a copy of what was generated to `~/Downloads/data_safety_pitchpole.csv`.

Regenerate it from a fresh sample with:

```bash
python3 store/fill_data_safety.py <sample.csv> store/data-safety.csv
```

The sample Play hands out arrives with example answers already in it, for Name
and Approximate location, with purposes that have nothing to do with this app.
The script clears every answer first and then sets only what is true, which is
why it exists: 783 rows edited by hand is 783 chances to leave one of Google's
examples behind and disclose something the app does not do.

## What is declared, and why

The app itself collects nothing. It has no analytics, no crash reporting and no
backend. Progress and settings are written to the device with
`shared_preferences` and stay there, and Play defines collection as
transmitting data off the device, so none of it is declarable.

Everything below is the Google Mobile Ads SDK, taken from Google's own
disclosure at
[developers.google.com/admob/android/privacy/play-data-disclosure](https://developers.google.com/admob/android/privacy/play-data-disclosure)
rather than from guesswork.

| Play data type | Collected | Shared | Purposes |
| --- | --- | --- | --- |
| Location / Approximate location | Yes | Yes | Advertising, Analytics, Fraud prevention |
| App activity / App interactions | Yes | Yes | Advertising, Analytics |
| App info and performance / Diagnostics | Yes | Yes | Analytics, App functionality |
| Device or other IDs | Yes | Yes | Advertising, Analytics, Fraud prevention |

Approximate location is on the list because AdMob receives the device's IP
address, from which a general region can be estimated. It is not GPS, and the
app requests no location permission.

Other answers:

- **Encrypted in transit: yes.** Google states the Mobile Ads SDK uses TLS, and
  the app sends nothing of its own.
- **All four marked required rather than optional.** Play means optional as in
  "the user can choose", and there is no in-app control over any of it. If a
  consent flow is added later, revisit this.
- **Not ephemeral.** The data leaves the device.
- **Account creation: none.** Play Games sign in uses an account the player
  already has; the app creates none of its own.
- **Data deletion request: no.** There is nothing held to delete, because there
  is no server. Resetting progress in settings and uninstalling both clear the
  device.

## The judgement call worth re-reading

Signing in to Play Games returns a display name and an avatar. The game shows
them on the button and writes the name to the device so the button can say who
is signed in on the next launch. It never transmits either.

Play's definition of collection is transmission off the device, so on that
reading this is not collection and **Personal info / Name is deliberately not
declared**. That is the defensible answer, and it is the one in the CSV. If you
would rather be conservative than correct, adding Name as collected for App
functionality is not wrong either, and no reviewer will argue with it.

## What changes if the app targets children

Nothing in the four data types above changes. Two things elsewhere do:

- `PSL_DATA_COLLECTION_COMPLIES_FAMILY_POLICY` is left blank, because it is
  only answered once the target age group includes children. Answer it in the
  console once that is settled.
- Declaring a child audience commits you to non-personalised, G-rated ads,
  which the app does not configure yet. See
  [../docs/play-store-checklist.md](../docs/play-store-checklist.md).

## Keep this in step with the app

The data safety form is a statement about the app as shipped, so it goes stale
the moment the app gains an SDK. Anything that adds analytics, crash reporting,
a backend, or a new ad network means coming back here first.

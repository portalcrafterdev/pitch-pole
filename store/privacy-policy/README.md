# Privacy policy page

`index.html` is the whole site: one self-contained file, no build step, no
external requests, no fonts or scripts to load. Play needs a public URL for it
before the app can be published.

## Deploying to Netlify

Drag this folder onto [app.netlify.com/drop](https://app.netlify.com/drop). It
is live immediately at a generated address, which you can rename under **Site
configuration > Change site name** to something like
`portalcrafter-pitchpole.netlify.app`.

To deploy from the repository instead, point Netlify at this repo and set:

| Setting | Value |
| --- | --- |
| Base directory | *(blank)* |
| Build command | *(blank)* |
| Publish directory | `store/privacy-policy` |

The URL to paste into the Play Console is the site root, for example
`https://portalcrafter-pitchpole.netlify.app/`, because the file is named
`index.html`.

## Before you publish it

Two things, both marked in the page itself:

1. **Delete the yellow note.** It is addressed to you, not to players, and it
   is inside a `<div class="panel" id="verify-before-publishing">`.
2. **Settle the children paragraph first.** It currently states that ads are
   limited to all-ages content and served without personalisation. That is a
   promise, and it is not true until the Mobile Ads SDK is configured that way
   in the app. Either configure it, or replace the paragraph with a statement
   that the app is not directed at children under 13, matching whatever you
   declare in the Play Console. See
   [docs/play-store-checklist.md](../../docs/play-store-checklist.md).

## Checking it

Play rejects a privacy policy URL that does not resolve, sits behind a login,
or is a file download rather than a page. Open the deployed URL in a private
window before pasting it in.

This page was written from what the code actually does, not from a template:
the app has no analytics, no crash reporting and no backend, and the only
third-party SDKs that leave the device are Google Mobile Ads and the platform
games service. It is not legal advice, and it is worth a read by someone
qualified if the app takes money or grows an audience.

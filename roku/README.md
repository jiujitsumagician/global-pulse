# Global Pulse — Roku Screensaver

A 10-foot, 1920×1080, overscan-safe **live world-news screensaver** for Roku,
built natively in BrightScript + SceneGraph (Roku has no WebGL/HTML, so this is
a flat equirectangular world map with glowing event markers — not a 3D globe).

## What it does

- Full-screen dark-space background with a public-domain **NASA Blue Marble
  equirectangular** world map (loaded by URL, drifts a few px to prevent burn-in).
- Fetches live events from `https://global-pulse-two.vercel.app/api/events` in a
  SceneGraph **Task** node (`roUrlTransfer` + `ParseJson`), and falls back to the
  bundled `events_sample.json` (12 events) if the network fails. Refreshes every
  5 minutes.
- Plots each event at its lat/lng as a glowing colored dot:
  - `x = (lng+180)/360 * mapW + mapLeft`
  - `y = (90-lat)/180 * mapH + mapTop`
  - Colors: Conflict `#ff5a4d`, Politics `#b98cff`, Disaster `#ff9e3d`,
    News `#5fe3ff`, Quake `#ffd23d`.
- Every ~7s it advances to the next event: a pulsing halo highlights that
  marker, and a semi-transparent **headline card** fades/slides in at the bottom
  showing the category tag, wrapped title, place, and a relative time.
- **Press OK / Select** on the remote to open a **QR overlay** for the current
  event — full headline, place/time, and a QR code (rendered as a `Poster`
  pointing at `api.qrserver.com`) that encodes the article URL so you can open it
  on your phone. **Back** or **Up** dismisses it. (Roku has no web browser, so a
  QR hand-off is used instead of opening the URL on the TV.)

## File layout

```
roku/
  manifest                       channel + screensaver metadata
  source/main.brs                RunScreenSaver() / Main() entry points
  components/
    ScreensaverScene.xml/.brs    the scene: map, markers, card, QR overlay
    NewsFetchTask.xml/.brs       Task node: HTTP fetch + sample fallback
  events_sample.json             bundled fallback data (12 events)
  images/README.txt              notes on optional/loaded assets (no binaries)
  README.md                      this file
```

## How it registers as a SCREENSAVER

A sideloaded SceneGraph channel becomes a selectable screensaver because
`source/main.brs` exports `Sub RunScreenSaver()`. That entry point — not a
manifest key — is what makes Roku list it under **Settings > Screensaver**.
`screensaver_title` in the manifest sets the friendly name. (`Main()` is also
exported so you can launch it from the Home screen to preview it as a channel.)

## Package & sideload

1. **Enable Developer Mode** on the Roku: on the remote press
   `Home ×3, Up ×2, Right, Left, Right, Left, Right`. Set a dev password and note
   the device IP it shows.
2. **Zip the channel.** Zip the *contents* of this `roku/` folder so that
   `manifest` is at the zip root (NOT a parent folder containing `roku/`):

   ```bash
   cd roku
   zip -r ../global-pulse.zip manifest source components images events_sample.json
   ```

   On Windows PowerShell:
   ```powershell
   Compress-Archive -Path manifest,source,components,images,events_sample.json -DestinationPath ..\global-pulse.zip -Force
   ```

3. **Upload via the dev web UI.** Browse to `http://<roku-ip>` (user `rokudev`,
   the password you set), then **Upload** the zip and click **Install / Replace**.
   The channel installs and launches.
4. **Set it as the active screensaver.** On the Roku go to
   **Settings > Theme > Screensaver** (or **Settings > Screensaver**), choose
   **Global Pulse**, and optionally set the wait time. It then runs whenever the
   device goes idle.

## Caveats

- **Key handling in true screensaver mode:** the QR overlay (OK to open, Back/Up
  to dismiss) is fully exercised when you launch Global Pulse as a *channel*
  (preview). When running as the *active screensaver*, Roku firmware may dismiss
  the saver on the first key press before the scene sees it, depending on OS
  version. The code is correct and SDK-standard; behavior is governed by the
  platform.
- **Map is hotlinked** from Wikimedia by default. For a robust shipping build,
  bundle a 2:1 JPG into `images/` and point `m.mapPoster.uri` at
  `pkg:/images/worldmap.jpg` (see `images/README.txt`).
- **No bundled binaries** (icons/splash/glow/map) — all are either loaded by URL
  or drawn with Rectangle nodes. Add the optional PNG/JPGs from
  `images/README.txt` for extra polish.
- **Rounded card corners:** SceneGraph `Rectangle` has no corner radius; the card
  uses straight edges. For rounded corners, swap in a 9-patch (`.9.png`) `Poster`.

## Changing the data source

The endpoint is set in two places — `NewsFetchTask.xml` (`endpoint` default) and
`ScreensaverScene.brs` `startFetch()` (`m.fetchTask.endpoint = ...`). Point both
at any URL returning the documented JSON shape:

```json
{ "updated": 1782604800000,
  "events": [ { "id":"...", "type":"News|Quake",
    "category":"Conflict|Politics|Disaster|News|Quake",
    "lat":0, "lng":0, "title":"...", "place":"...",
    "time":1782602100000, "url":"...", "mag":null } ] }
```

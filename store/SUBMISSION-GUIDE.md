# Global Pulse — Roku Channel Store Submission Guide

Goal: publish **Global Pulse** as a **paid (pay-to-install) screensaver** on the
public Roku Channel Store.

Everything in `store/` is prepared and ready. The steps below are the parts that
require **your Roku account** (Claude can't do these for you). Each step notes
who does it.

---

## Status snapshot

**Ready (in this repo):**
- ✅ Channel package — `global-pulse-roku.zip` (built from `roku/`)
- ✅ Certification-clean: dual-mode (no input as a screensaver), exits on keypress
- ✅ Manifest with `screensaver_title`, versioned icons + splash
- ✅ Marketing screenshots — `store/screenshots/`
- ✅ Listing copy — `store/LISTING.md`
- ✅ Privacy policy text — `store/PRIVACY.md` (needs hosting at a public URL)

**Needs you:**
- ⬜ Roku developer account (free)
- ⬜ Roku Pay payout setup (banking + tax) — required for a *paid* channel
- ⬜ Host the privacy policy at a public URL
- ⬜ Create the channel, upload the package, fill the listing, set the price
- ⬜ Submit for certification

---

## Phase 0 — Roku developer account  *(you, ~10 min, free)*
1. Go to **https://developer.roku.com** and sign in with your Roku account
   (the same account your devices use). If you don't have a Roku account, create
   one at roku.com first.
2. Accept the **Roku Developer Agreement** the first time you open the dashboard.
3. You now have access to the **Developer Dashboard** (developer.roku.com/dashboard).

> Registration and publishing are free. There is no listing fee.

## Phase 1 — Payout / Roku Pay setup  *(you — do this early; it gates a paid channel)*
A paid channel can't go live until payouts are configured.
1. Dashboard → **Payment & Tax** (account settings).
2. Complete **banking** and **tax** info (W-9 / business details).
3. This can take a little time to verify — start it now so it's ready by cert.

## Phase 2 — Host the privacy policy  *(you, ~5 min)*
1. Publish the text in `store/PRIVACY.md` at a public URL you control, e.g.
   `https://global-pulse-two.vercel.app/privacy` or a dicksoft.io page.
2. Keep the URL — you'll paste it into the listing.

## Phase 3 — Create the channel  *(you)*
1. Dashboard → **My Channels** → **Add Channel** → **Public**.
2. Channel type: **Screensaver**. Name: **Global Pulse**.
3. Upload the package: `global-pulse-roku.zip`.
   - Rebuild it any time with: `python tools/pack.py` *(see note below)* or the
     packaging step Claude uses.

## Phase 4 — Store listing  *(you, copy from `store/LISTING.md`)*
Fill in:
- **Name:** Global Pulse
- **Category:** Screensavers
- **Short + long description:** from `store/LISTING.md`
- **Screenshots:** upload 3–6 from `store/screenshots/` (1280×720 accepted)
- **Channel poster art / icons:** the dashboard lists the exact required sizes;
  our source art is in `roku/images/` (focus icons + splash). Generate any extra
  sizes the dashboard asks for from those (Claude can produce them on request).
- **Privacy policy URL:** the one from Phase 2
- **Support email / contact:** your support address

## Phase 5 — Monetization (pay-to-install)  *(you)*
1. Channel → **Monetization** → set method to **Paid (pay-to-install)**.
2. Set the price (recommended: **$2.99** one-time — see LISTING.md).
3. No in-channel purchase code is required for pay-to-install (that's only for
   subscriptions / in-app purchases).

## Phase 6 — Submit for certification  *(you)*
1. Channel → **Submit for Publishing**.
2. Roku runs the **certification checklist** (performance, screensaver behavior,
   no crashes, exits on keypress, no system-screensaver interference). Our build
   is designed to pass these.
3. Certification typically takes **several days** and may come back with notes.
   Send any feedback to Claude and we'll turn fixes around fast.

---

## Certification notes we've already handled
- Standalone screensaver (no embedded screensaver in a non-screensaver app).
- `screensaver_title` present; registers via `RunScreenSaver()`.
- **No user input as a screensaver** — keys pass through so the firmware
  dismisses the saver (the OK→QR feature is active only in channel-launch mode).
- Does not override or interfere with the system screensaver.
- Bundled assets (globe video + stills) load from the package, not hotlinked.

## Known polish items (optional, before final marketing shots)
- Article **blurb** sometimes scrapes social/byline/paywall text — fix in
  `api/article.js` (server) then redeploy to Vercel.
- Occasional **geolocation mismatch** (story tagged to the wrong country) — fix
  in `api/events.js` placement heuristics.
- Neither blocks certification; both improve polish.

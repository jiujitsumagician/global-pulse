# Global Pulse — Amazon Appstore Submission Guide (Fire TV)

Everything is prepared. This walks you through the Amazon Developer Console from
zero to "Submit for review." ~20 minutes.

## What you have ready
- **APK:** `C:\Users\mrwil\Desktop\GlobalPulse-firetv.apk` (signed, v1+v2)
- **Icons:** `store/firetv/icon_512.png`, `icon_114.png`
- **Screenshots:** `store/firetv/screenshots/firetv_shot_1..4.png` (1920×1080)
- **Listing copy:** `store/firetv/LISTING.md`
- **Privacy URL:** https://jiujitsumagician.github.io/global-pulse/privacy.html

---

## Step 1 — Create a free Amazon Developer account
1. Go to **https://developer.amazon.com** → **Sign in** (top right).
2. Sign in with your Amazon account (or create one). Use the DSIO business email.
3. Accept the **App Distribution Agreement**.
4. Fill **Developer profile**: company name (DSIO), address, website.
   - The Amazon Appstore developer account is **free** — no annual fee (unlike
     Google Play's $25).
5. If you want to charge $2.99, complete **Payment & tax** (bank + tax interview,
   IRS W-9). You can do this now or before you flip the app to Paid.

## Step 2 — Create the app
1. In the console go to the **Appstore** dashboard → **Apps & Services** →
   **My Apps** → **Add New App** → **Android**.
2. **App title:** `Global Pulse`
3. Default language: English (US). → **Save**. This creates the app record and
   drops you into the tabbed submission form.

## Step 3 — Availability & Pricing
1. **Availability:** All countries (or your pick).
2. **Pricing:**
   - For **Paid $2.99**: set Free/Paid → **Paid**, list price **$2.99 USD**
     (Amazon auto-converts other currencies). *Requires the tax interview done.*
   - If tax isn't ready and you want to ship today, set **Free** now and switch
     to Paid later via an app update.

## Step 4 — Upload the APK
1. Open the **APKs / Binary** tab → **Upload your APK**.
2. Select `C:\Users\mrwil\Desktop\GlobalPulse-firetv.apk`.
3. Amazon reads the manifest. Confirm it shows:
   - Package `io.dsio.globalpulse`, versionCode 1, versionName 1.0
   - Permission: INTERNET
4. **Device targeting / filtering:** Amazon will auto-detect device support from
   the leanback manifest. In the device list, **keep Fire TV devices checked**;
   **uncheck non-Fire-TV** phones/tablets (this is a TV-only leanback app).
   - If Amazon warns about "supports touchscreen: not required" — that's expected
     and correct for a TV app; proceed.
5. **Note on signing:** Amazon re-signs the APK with your account's key. The
   throwaway keystore we used doesn't matter — ignore any "debug/self-signed"
   note. (The APK is real-release-signed v2, so it passes Fire OS 8 checks.)

## Step 5 — App details (listing)
Copy from `store/firetv/LISTING.md`:
1. **Short description** and **Long description** — paste the two blocks.
2. **Category:** News & Weather.
3. **Keywords/search terms:** paste the keyword line.
4. **Contact info + Privacy policy URL:**
   https://jiujitsumagician.github.io/global-pulse/privacy.html

## Step 6 — Images & multimedia
Upload from `store/firetv/`:
1. **Small icon (114×114):** `icon_114.png`
2. **Large icon (512×512):** `icon_512.png`
3. **Screenshots (min 3):** `screenshots/firetv_shot_1.png` … `firetv_shot_4.png`
   (all 1920×1080 — real Fire TV captures).
4. **Feature graphic / banner (optional, 1280×720):** you can reuse the Roku
   poster art (`store/assets/poster_540x405.png` upscaled) or skip if optional.

## Step 7 — Content rating
1. Open **Content Rating** → answer the **IARC questionnaire**.
2. Answers: no violence / sex / profanity / gambling / drugs / user-to-user
   comms; the app **does display third-party news headlines and photos**.
3. Submit the questionnaire → you'll get an automatic rating (expected: low /
   Everyone-ish). See `LISTING.md` → Content rating.

## Step 8 — Review & Submit
1. The dashboard shows a checklist; every tab should have a green check.
2. Click **Submit App**.
3. Amazon review typically takes **1–3 business days**. You'll get email on
   approval or if they need changes.

---

## Common gotchas
- **"APK not signed / debug":** ignore — Amazon re-signs. Ours is release v2-signed
  anyway, so no Fire OS 8 rejection.
- **"App supports non-TV devices":** uncheck phones/tablets in device targeting so
  it lists cleanly as a Fire TV app.
- **Paid app greyed out:** finish the tax/bank interview first (Step 1.5).
- **WebView / internet:** the app loads the live globe from
  `https://global-pulse-two.vercel.app/?tv=1`. Keep that Vercel deploy live —
  if it goes down, the app shows a blank WebView. (It's already deployed.)

## After approval
- To update: bump `versionCode` (and `versionName`) in
  `firetv/app/build.gradle`, rebuild `assembleRelease`, upload the new APK as a
  new version in the console.

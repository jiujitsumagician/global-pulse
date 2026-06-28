# Global Pulse — Fire TV app

A leanback Android app that runs the live Global Pulse globe full-screen on Fire TV.
The D-pad navigates events; **OK** on an event opens the article in a native in-app
browser (D-pad ↑/↓ scrolls), and **Back** returns to the globe.

## Build & sideload
```
# from this firetv/ folder, with Android SDK installed:
./gradlew assembleRelease            # or open in Android Studio and Run
# install to a Fire TV on your network (enable ADB debugging on the device):
adb connect <firetv-ip>:5555
adb install -r app/build/outputs/apk/release/app-release-unsigned.apk
```
Launch "Global Pulse" from the Fire TV apps row.

## Notes
- Loads the hosted app at `https://global-pulse-two.vercel.app/?tv=1.4` — change `APP_URL`
  in `MainActivity.java` to self-host.
- **True OS screensaver slot:** Amazon controls the Fire TV system screensaver, so this
  ships as a launchable ambient app (the standard third-party approach). It can also be
  set as a daydream/idle app via Android `DreamService` if desired (extra activity).
- For a Google-signed release APK, add a signing config; the unsigned APK sideloads fine in
  developer mode.

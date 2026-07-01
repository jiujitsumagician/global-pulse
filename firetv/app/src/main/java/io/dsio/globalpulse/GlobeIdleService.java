package io.dsio.globalpulse;

import android.accessibilityservice.AccessibilityService;
import android.content.Intent;
import android.media.AudioManager;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.util.Log;
import android.view.KeyEvent;
import android.view.accessibility.AccessibilityEvent;

/** Screensaver behaviour for Fire TV, which blocks third-party system
 *  screensavers. This accessibility service watches for user inactivity
 *  (navigation + key events); after gp_idle_seconds of no input it launches the
 *  Global Pulse globe over whatever's on screen. Any button press dismisses it
 *  (MainActivity finishes itself in screensaver mode), returning the TV to
 *  normal use. It skips launching while audio/video is actively playing.
 *  Once enabled it auto-starts on boot, so it's set-and-forget. */
public class GlobeIdleService extends AccessibilityService {
  private final Handler h = new Handler(Looper.getMainLooper());
  private final Runnable idle = new Runnable() { public void run() { maybeStart(); } };

  private int idleMs() {
    int s = 240;
    try { s = Settings.Global.getInt(getContentResolver(), "gp_idle_seconds", 240); } catch (Exception e) {}
    if (s < 10) s = 10;
    return s * 1000;
  }

  private void reset() {
    int ms = idleMs();
    h.removeCallbacks(idle);
    h.postDelayed(idle, ms);
    Log.d("GPIDLE", "reset: fire in " + ms + "ms");
  }

  private void maybeStart() {
    Log.d("GPIDLE", "maybeStart: saverShowing=" + MainActivity.saverShowing);
    if (MainActivity.saverShowing) { reset(); return; }
    try {
      AudioManager am = (AudioManager) getSystemService(AUDIO_SERVICE);
      if (am != null && am.isMusicActive()) { Log.d("GPIDLE", "skip: music active"); reset(); return; }
    } catch (Exception e) {}
    try {
      Intent it = new Intent(this, MainActivity.class);
      it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
      it.putExtra("screensaver", true);
      startActivity(it);
      Log.d("GPIDLE", "startActivity(globe) OK");
    } catch (Exception e) {
      Log.e("GPIDLE", "startActivity FAILED", e);
    }
    reset();
  }

  @Override protected void onServiceConnected() { Log.d("GPIDLE", "onServiceConnected"); reset(); }
  // Idle is driven ONLY by real remote input (key events), which this service
  // receives globally. Accessibility events are ignored on purpose — the Fire TV
  // launcher emits periodic background events that would otherwise keep resetting
  // the timer so the screensaver could never fire while sitting on the home screen.
  @Override public void onAccessibilityEvent(AccessibilityEvent e) {}
  @Override protected boolean onKeyEvent(KeyEvent event) {
    Log.d("GPIDLE", "onKeyEvent code=" + event.getKeyCode());
    reset(); return false;
  }
  @Override public void onInterrupt() {}
}

package io.dsio.globalpulse;

import android.app.ActivityManager;
import android.content.BroadcastReceiver;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.provider.Settings;

import java.util.List;

/** Re-arms the idle screensaver after a reboot. Fire OS leaves adb-enabled
 *  accessibility services suspended after boot; the service only re-binds when
 *  the enabled-services setting genuinely changes (clear -> set) in the fresh
 *  post-boot process. Uses goAsync() + a worker thread so the whole clear/wait/
 *  set sequence completes before the receiver's process can be reclaimed (a
 *  plain postDelayed would be killed first). Requires WRITE_SECURE_SETTINGS,
 *  granted once via adb:
 *  `pm grant io.dsio.globalpulse android.permission.WRITE_SECURE_SETTINGS`. */
public class BootReceiver extends BroadcastReceiver {
  static final String SVC = "io.dsio.globalpulse/io.dsio.globalpulse.GlobeIdleService";

  @Override public void onReceive(final Context ctx, Intent it) {
    final PendingResult pr = goAsync();
    new Thread(new Runnable() { public void run() {
      try {
        ContentResolver cr = ctx.getApplicationContext().getContentResolver();
        // 1) Clear so the system unbinds the (suspended) boot-time a11y service.
        Settings.Secure.putInt(cr, Settings.Secure.ACCESSIBILITY_ENABLED, 0);
        Settings.Secure.putString(cr, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES, "");
        Thread.sleep(1500);
        // 2) Kill the main app process (same uid) so the next enable binds the
        //    a11y service into a genuinely fresh process — Fire OS only clean-binds
        //    that way. This receiver runs in :boot, so it survives the kill.
        killMain(ctx);
        Thread.sleep(1500);
        // 3) Re-enable -> system starts a fresh main process and clean-binds.
        Settings.Secure.putString(cr, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES, SVC);
        Settings.Secure.putInt(cr, Settings.Secure.ACCESSIBILITY_ENABLED, 1);
      } catch (Exception e) {
        // WRITE_SECURE_SETTINGS not granted or interrupted -> nothing we can do.
      } finally {
        pr.finish();
      }
    }}).start();
  }

  /** Kill the main app process (not this :boot process) so a11y re-binds fresh. */
  private void killMain(Context ctx) {
    try {
      ActivityManager am = (ActivityManager) ctx.getSystemService(Context.ACTIVITY_SERVICE);
      List<ActivityManager.RunningAppProcessInfo> ps = am.getRunningAppProcesses();
      if (ps == null) return;
      int mine = android.os.Process.myPid();
      for (ActivityManager.RunningAppProcessInfo p : ps) {
        if ("io.dsio.globalpulse".equals(p.processName) && p.pid != mine) {
          android.os.Process.killProcess(p.pid);
        }
      }
    } catch (Exception e) {}
  }
}


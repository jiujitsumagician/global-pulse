package io.dsio.globalpulse;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.KeyEvent;
import android.view.WindowManager;
import android.webkit.ConsoleMessage;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

/** Fire TV host: shows the live Global Pulse globe full-screen. The web app calls
 *  GPNative.openArticle(url) when OK is pressed on an event; we open a native reader. */
public class MainActivity extends Activity {
  static final String APP_URL = "https://global-pulse-two.vercel.app/?tv=1";
  /** True while the globe is on screen as the idle screensaver (see GlobeIdleService). */
  static volatile boolean saverShowing = false;
  WebView web;
  boolean saverMode = false;

  @Override protected void onCreate(Bundle b) {
    super.onCreate(b);
    getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    applySaverMode(getIntent());
    WebView.setWebContentsDebuggingEnabled(true);   // allow chrome://inspect + logging
    web = new WebView(this);
    setContentView(web);
    WebSettings s = web.getSettings();
    s.setJavaScriptEnabled(true);
    s.setDomStorageEnabled(true);
    s.setMediaPlaybackRequiresUserGesture(false);
    // The display is 1920x1080 but at density 2.0 the WebView's CSS viewport is
    // only 960 wide, which squishes the desktop layout. The page's meta viewport
    // asks for width=1920; honor it and zoom-to-fit so it renders like a 1080p
    // desktop (matching the web/PC version).
    s.setUseWideViewPort(true);
    s.setLoadWithOverviewMode(true);
    web.setWebViewClient(new WebViewClient());
    web.setWebChromeClient(new WebChromeClient() {
      @Override public boolean onConsoleMessage(ConsoleMessage m) {
        Log.d("GPWEB", m.message() + " @ " + m.sourceId() + ":" + m.lineNumber());
        return true;
      }
    });
    web.addJavascriptInterface(new Bridge(), "GPNative");

    // Allow a test URL override for iteration: adb shell am start -n ... --es url http://host:port/
    String url = APP_URL;
    Intent it = getIntent();
    if (it != null && it.getStringExtra("url") != null) url = it.getStringExtra("url");
    web.loadUrl(url);
  }

  // --- Screensaver mode: launched by GlobeIdleService on idle; any key dismisses. ---
  private void applySaverMode(Intent it) {
    saverMode = it != null && it.getBooleanExtra("screensaver", false);
    if (saverMode) saverShowing = true;
  }

  @Override protected void onNewIntent(Intent it) {
    super.onNewIntent(it);
    setIntent(it);
    applySaverMode(it);
  }

  @Override public boolean dispatchKeyEvent(KeyEvent e) {
    // In screensaver mode, the first real key press dismisses the globe and
    // hands the TV back. In normal (user-launched) mode, keys behave normally.
    if (saverMode && e.getAction() == KeyEvent.ACTION_UP) { saverShowing = false; finish(); return true; }
    if (saverMode) return true;  // swallow the matching ACTION_DOWN so nothing acts on it
    return super.dispatchKeyEvent(e);
  }

  @Override protected void onDestroy() {
    if (saverMode) saverShowing = false;
    super.onDestroy();
  }

  class Bridge {
    @JavascriptInterface public void openArticle(final String url) {
      runOnUiThread(new Runnable() { public void run() {
        startActivity(new Intent(MainActivity.this, ReaderActivity.class).putExtra("url", url));
      }});
    }
  }
}

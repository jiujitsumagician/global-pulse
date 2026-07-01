package io.dsio.globalpulse;

import android.service.dreams.DreamService;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

/** Fire TV / Android screensaver ("Daydream") that shows the live Global Pulse
 *  globe when the device goes idle. Same hosted web app as MainActivity, wrapped
 *  as a DreamService so the OS can run it as the active screensaver. (Ignored on
 *  Fire OS 8+, which blocks third-party screensavers — those devices use the
 *  launchable app instead.) */
public class GlobeDreamService extends DreamService {
  private WebView web;

  @Override public void onAttachedToWindow() {
    super.onAttachedToWindow();
    setInteractive(false);
    setFullscreen(true);
    setScreenBright(true);
    web = new WebView(this);
    WebSettings s = web.getSettings();
    s.setJavaScriptEnabled(true);
    s.setDomStorageEnabled(true);
    s.setMediaPlaybackRequiresUserGesture(false);
    s.setUseWideViewPort(true);
    s.setLoadWithOverviewMode(true);
    web.setWebViewClient(new WebViewClient());
    setContentView(web);
    web.loadUrl(MainActivity.APP_URL);
  }

  @Override public void onDetachedFromWindow() {
    if (web != null) { web.destroy(); web = null; }
    super.onDetachedFromWindow();
  }
}

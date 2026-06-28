package io.dsio.globalpulse;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

/** Fire TV host: shows the live Global Pulse globe full-screen. The web app calls
 *  GPNative.openArticle(url) when OK is pressed on an event; we open a native reader. */
public class MainActivity extends Activity {
  static final String APP_URL = "https://global-pulse-two.vercel.app/?tv=1.4";
  WebView web;

  @Override protected void onCreate(Bundle b) {
    super.onCreate(b);
    getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    web = new WebView(this);
    setContentView(web);
    WebSettings s = web.getSettings();
    s.setJavaScriptEnabled(true);
    s.setDomStorageEnabled(true);
    s.setMediaPlaybackRequiresUserGesture(false);
    web.setWebViewClient(new WebViewClient());
    web.setWebChromeClient(new WebChromeClient());
    web.addJavascriptInterface(new Bridge(), "GPNative");
    web.loadUrl(APP_URL);
  }

  class Bridge {
    @JavascriptInterface public void openArticle(final String url) {
      runOnUiThread(new Runnable() { public void run() {
        startActivity(new Intent(MainActivity.this, ReaderActivity.class).putExtra("url", url));
      }});
    }
  }
}

package io.dsio.globalpulse;

import android.app.Activity;
import android.os.Bundle;
import android.view.KeyEvent;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

/** Native in-app browser for an article. D-pad up/down scrolls; Back returns to the globe. */
public class ReaderActivity extends Activity {
  WebView web;

  @Override protected void onCreate(Bundle b) {
    super.onCreate(b);
    web = new WebView(this);
    setContentView(web);
    WebSettings s = web.getSettings();
    s.setJavaScriptEnabled(true);
    s.setDomStorageEnabled(true);
    s.setLoadWithOverviewMode(true);
    s.setUseWideViewPort(true);
    s.setBuiltInZoomControls(false);
    web.setWebViewClient(new WebViewClient());
    web.setWebChromeClient(new WebChromeClient());
    web.setFocusableInTouchMode(true);
    web.requestFocus();
    String url = getIntent().getStringExtra("url");
    web.loadUrl(url != null ? url : "about:blank");
  }

  @Override public boolean onKeyDown(int code, KeyEvent e) {
    if (code == KeyEvent.KEYCODE_DPAD_DOWN) { web.scrollBy(0, 170); return true; }
    if (code == KeyEvent.KEYCODE_DPAD_UP)   { web.scrollBy(0, -170); return true; }
    if (code == KeyEvent.KEYCODE_DPAD_RIGHT){ web.scrollBy(0, 600); return true; }
    if (code == KeyEvent.KEYCODE_DPAD_LEFT) { web.scrollBy(0, -600); return true; }
    return super.onKeyDown(code, e);
  }

  @Override public void onBackPressed() { finish(); }   // back to the globe
}

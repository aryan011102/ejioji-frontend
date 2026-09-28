package com.ejioji

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Other people's profiles and chats, kept out of screenshots, recordings
        // and the recent-apps preview while one is on screen
        // (lib/core/native/screen_capture.dart). FLAG_SECURE is Android's own
        // switch for this, so unlike iOS nothing here is a workaround. The
        // answer is whether a recording is running, which Android never needs
        // to report: a secure window records as black.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "theonebytwo/screen_capture")
            .setMethodCallHandler { call, result ->
                if (call.method != "setProtected") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (call.arguments == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(false)
            }
    }
}

package dev.sidescreen.side_screen

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var displays: ExternalDisplayCoordinator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        displays = ExternalDisplayCoordinator(this, flutterEngine) { presenting ->
            if (presenting) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    override fun onPostResume() {
        super.onPostResume()
        displays?.resume()
    }

    override fun onStop() {
        displays?.suspend()
        super.onStop()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        displays?.dispose()
        displays = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}

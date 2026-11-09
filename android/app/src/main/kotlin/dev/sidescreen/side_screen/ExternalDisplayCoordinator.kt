package dev.sidescreen.side_screen

import android.app.Activity
import android.app.Presentation
import android.content.Context
import android.content.Intent
import android.content.ActivityNotFoundException
import android.net.Uri
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.hardware.display.DisplayManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.View
import android.view.WindowManager
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.android.ExclusiveAppComponent
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/** Hosts one secondary display. The phone remains the session's authority. */
class ExternalDisplayCoordinator(
    private val activity: Activity,
    engine: FlutterEngine,
    private val onPresenting: (Boolean) -> Unit,
) : DisplayManager.DisplayListener {
    private val manager = activity.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private val handler = Handler(Looper.getMainLooper())
    private val preferences = activity.getSharedPreferences("side_screen", Context.MODE_PRIVATE)
    private val primary = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
    private val engines = FlutterEngineGroup(activity.applicationContext)
    private var secondary: MethodChannel? = null
    private var presentation: WorkspacePresentation? = null
    private var state: Map<String, Any?>? = readState()
    private var foreground = false
    private var disposed = false
    private var error: String? = null
    private var retryCount = 0
    private val refreshTask = Runnable { refresh() }

    init {
        primary.setMethodCallHandler { call, result -> handle(call, result, false) }
        manager.registerDisplayListener(this, handler)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result, external: Boolean) {
        when (call.method) {
            "openChrome" -> {
                val value = call.argument<String>("url")
                val uri = value?.let(Uri::parse)
                if (uri == null || uri.scheme !in listOf("http", "https") || uri.host.isNullOrEmpty()) {
                    result.error("invalid_url", "Địa chỉ Chrome không hợp lệ.", null)
                    return
                }
                try {
                    val intent = Intent(Intent.ACTION_VIEW, uri)
                        .addCategory(Intent.CATEGORY_BROWSABLE)
                        .setPackage("com.android.chrome")
                    activity.startActivity(intent)
                    result.success(null)
                } catch (_: ActivityNotFoundException) {
                    result.error("chrome_unavailable", "Chưa cài Google Chrome trên điện thoại.", null)
                } catch (_: SecurityException) {
                    result.error("chrome_unavailable", "Hệ thống không cho phép mở Chrome.", null)
                }
            }
            "initialize" -> {
                if (!external) refresh()
                result.success(mapOf("status" to status(), "state" to state))
            }
            "refresh" -> {
                if (!external) { retryCount = 0; refresh() }
                result.success(null)
            }
            "publishState" -> {
                if (!external) asMap(call.arguments)?.let {
                    state = it
                    secondary?.invokeMethod("stateChanged", it)
                }
                result.success(null)
            }
            "saveState" -> {
                if (!external) asMap(call.arguments)?.let {
                    preferences.edit().putString("workspace.v1", JSONObject(it).toString()).apply()
                }
                result.success(null)
            }
            "publishPointer" -> {
                if (!external) asMap(call.arguments)?.let { pointer ->
                    val next = (state ?: emptyMap()).toMutableMap()
                    for (key in listOf("cursorX", "cursorY")) {
                        val value = (pointer[key] as? Number)?.toDouble()
                        if (value != null && value.isFinite()) next[key] = value
                    }
                    state = next
                    secondary?.invokeMethod("pointerChanged", pointer)
                }
                result.success(null)
            }
            "dispatchAction" -> {
                if (external) asMap(call.arguments)?.let { primary.invokeMethod("action", it) }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun resume() { foreground = true; retryCount = 0; refresh() }

    fun suspend() {
        foreground = false
        handler.removeCallbacks(refreshTask)
        dismiss()
        notifyStatus()
    }

    private fun displays(): List<Display> = manager
        .getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
        .filter { it.displayId != Display.DEFAULT_DISPLAY && it.isValid }
        .sortedBy { it.displayId }

    private fun refresh() {
        if (disposed) return
        val display = displays().firstOrNull()
        if (!foreground || display == null) {
            dismiss()
            error = null
        } else if (presentation?.display?.displayId != display.displayId || presentation?.isShowing != true) {
            dismiss()
            var unownedEngine: FlutterEngine? = null
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                val entrypoint = DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "externalDisplayMain")
                val engine = engines.createAndRunEngine(activity.applicationContext, entrypoint)
                unownedEngine = engine
                secondary = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).apply {
                    setMethodCallHandler { call, result -> handle(call, result, true) }
                }
                val next = WorkspacePresentation(activity, display, engine)
                @Suppress("DEPRECATION")
                check(next.window?.windowManager?.defaultDisplay?.displayId == display.displayId) {
                    "Presentation window context does not match the target display"
                }
                presentation = next
                unownedEngine = null // Ownership transfers to the Presentation.
                next.setOnDismissListener {
                    if (presentation === next) {
                        presentation = null
                        secondary?.setMethodCallHandler(null)
                        secondary = null
                        onPresenting(false)
                        notifyStatus()
                    }
                    next.release()
                }
                next.show()
                engine.lifecycleChannel.appIsResumed()
                error = null
                retryCount = 0
                onPresenting(true)
            } catch (failure: Exception) {
                dismiss()
                unownedEngine?.destroy()
                error = "Không thể mở màn hình. Hãy thử lại hoặc đóng rồi mở app với màn hình đang cắm."
                android.util.Log.w("SideScreen", "External presentation was declined", failure)
                // The display may not yet be ready when the hot-plug event arrives.
                // A bounded retry avoids either an engine leak or a launch loop.
                if (failure is WindowManager.InvalidDisplayException && foreground && retryCount < 3) {
                    retryCount++
                    handler.removeCallbacks(refreshTask)
                    handler.postDelayed(refreshTask, 300L * retryCount)
                }
            }
        }
        notifyStatus()
    }

    private fun status(): Map<String, Any?> {
        val display = displays().firstOrNull()
        return mapOf(
            "nativeAvailable" to true,
            "supportsPointerUpdates" to true,
            "connected" to (display != null),
            "presenting" to (presentation?.isShowing == true),
            "name" to display?.name,
            "width" to display?.mode?.physicalWidth,
            "height" to display?.mode?.physicalHeight,
            "error" to error,
        )
    }

    private fun notifyStatus() {
        if (!disposed) primary.invokeMethod("displayChanged", status())
    }

    private fun dismiss() {
        val current = presentation
        presentation = null
        secondary?.setMethodCallHandler(null)
        secondary = null
        current?.setOnDismissListener(null)
        current?.dismiss()
        current?.release()
        onPresenting(false)
    }

    private fun scheduleRefresh() {
        retryCount = 0
        handler.removeCallbacks(refreshTask)
        handler.postDelayed(refreshTask, 180)
    }
    override fun onDisplayAdded(displayId: Int) = scheduleRefresh()
    override fun onDisplayChanged(displayId: Int) = scheduleRefresh()
    override fun onDisplayRemoved(displayId: Int) = scheduleRefresh()

    fun dispose() {
        disposed = true
        handler.removeCallbacks(refreshTask)
        manager.unregisterDisplayListener(this)
        dismiss()
        primary.setMethodCallHandler(null)
    }

    private fun readState(): Map<String, Any?>? = try {
        preferences.getString("workspace.v1", null)?.let { jsonToMap(JSONObject(it)) }
    } catch (_: Exception) { null }

    companion object {
        private const val CHANNEL = "dev.sidescreen/display"
        private fun asMap(raw: Any?): Map<String, Any?>? {
            if (raw !is Map<*, *>) return null
            return raw.entries.filter { it.key is String }.associate { it.key as String to it.value }
        }
        private fun jsonToMap(json: JSONObject): Map<String, Any?> = json.keys().asSequence()
            .associateWith { jsonValue(json.get(it)) }
        private fun jsonValue(value: Any?): Any? = when (value) {
            JSONObject.NULL -> null
            is JSONObject -> jsonToMap(value)
            is JSONArray -> (0 until value.length()).map { jsonValue(value.get(it)) }
            else -> value
        }
    }
}

private class WorkspacePresentation(
    private val activity: Activity,
    display: Display,
    private val engine: FlutterEngine,
) : Presentation(activity.applicationContext, display) {
    private var flutterView: FlutterView? = null
    private var released = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window?.setTitle("SideScreen external workspace")
        window?.setBackgroundDrawable(ColorDrawable(Color.rgb(23, 58, 70)))
        window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        @Suppress("DEPRECATION")
        window?.decorView?.systemUiVisibility = View.SYSTEM_UI_FLAG_FULLSCREEN or
            View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        val view = FlutterView(context)
        flutterView = view
        setContentView(view)
        // WebView and other platform-view plugins need an Activity and lifecycle
        // even though this engine renders into a Presentation on another display.
        engine.activityControlSurface.attachToActivity(object : ExclusiveAppComponent<Activity> {
            override fun getAppComponent(): Activity = activity
            override fun detachFromFlutterEngine() {
                flutterView?.detachFromFlutterEngine()
                flutterView = null
            }
        }, (activity as LifecycleOwner).lifecycle)
        view.attachToFlutterEngine(engine)
    }

    fun release() {
        if (released) return
        released = true
        flutterView?.detachFromFlutterEngine()
        flutterView = null
        engine.activityControlSurface.detachFromActivity()
        engine.lifecycleChannel.appIsDetached()
        engine.destroy()
    }
}

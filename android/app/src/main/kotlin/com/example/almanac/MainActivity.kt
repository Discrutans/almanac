package com.example.almanac

import android.os.Build
import android.os.Bundle
import android.view.Display
import android.view.Surface
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.example.almanac/high_refresh_rate"
        private const val WIDGET_CHANNEL = "com.example.almanac/today_widget"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> result.success(enableHighRefreshRate())
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateToday" -> {
                        val title = call.argument<String>("title") ?: "Today"
                        val lines = call.argument<String>("lines") ?: ""
                        val prefs = getSharedPreferences(
                            TodayEventsWidget.PREFS,
                            MODE_PRIVATE,
                        )
                        prefs.edit()
                            .putString(TodayEventsWidget.KEY_TITLE, title)
                            .putString(TodayEventsWidget.KEY_LINES, lines)
                            .apply()
                        TodayEventsWidget.updateAll(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableHighRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        enableHighRefreshRate()
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        enableHighRefreshRate()
    }

    private fun enableHighRefreshRate(): Double {
        val display = resolveDisplay() ?: return 60.0
        val bestMode = pickHighestRefreshMode(display)
        val refreshRate = (bestMode?.refreshRate ?: display.refreshRate).toDouble()

        val params = window.attributes
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && bestMode != null) {
            params.preferredDisplayModeId = bestMode.modeId
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            params.preferredRefreshRate = refreshRate.toFloat()
        }
        window.attributes = params
        applySurfaceFrameRate(refreshRate)
        disableFrameRatePowerSavings()
        return refreshRate
    }

    /// Android 15+ иначе может сбросить 120 Гц до 60 ради экономии батареи.
    private fun disableFrameRatePowerSavings() {
        if (Build.VERSION.SDK_INT < 35) return
        try {
            val setter = window.javaClass.methods.firstOrNull { method ->
                method.name == "setFrameRatePowerSavingsBalanced" &&
                    method.parameterTypes.size == 1
            }
            setter?.invoke(window, false)
        } catch (_: Throwable) {
            // Property missing on this SDK / OEM build.
        }
    }

    private fun pickHighestRefreshMode(display: Display): Display.Mode? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
        val current = display.mode
        val sameSize = display.supportedModes.filter {
            it.physicalWidth == current.physicalWidth &&
                it.physicalHeight == current.physicalHeight
        }
        return sameSize.maxByOrNull { it.refreshRate }
            ?: display.supportedModes.maxByOrNull { it.refreshRate }
    }

    private fun applySurfaceFrameRate(refreshRate: Double) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        window.decorView.post {
            val surface = findSurfaceView(window.decorView)?.holder?.surface ?: return@post
            if (!surface.isValid) return@post
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                surface.setFrameRate(
                    refreshRate.toFloat(),
                    Surface.FRAME_RATE_COMPATIBILITY_FIXED_SOURCE,
                    Surface.CHANGE_FRAME_RATE_ALWAYS,
                )
            } else {
                surface.setFrameRate(
                    refreshRate.toFloat(),
                    Surface.FRAME_RATE_COMPATIBILITY_FIXED_SOURCE,
                )
            }
        }
    }

    private fun findSurfaceView(view: View): SurfaceView? {
        if (view is SurfaceView) return view
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                findSurfaceView(view.getChildAt(i))?.let { return it }
            }
        }
        return null
    }

    private fun resolveDisplay(): Display? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        }
    }
}

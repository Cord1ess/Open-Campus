package com.cord1ess.opencampus

import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Opt into the panel's highest refresh rate (90/120Hz) instead of the
        // default 60Hz. Flutter renders at whatever mode the surface is in, so we
        // pick the display mode with the highest refresh rate at the native
        // resolution and let the system honour it.
        enableHighRefreshRate()
    }

    private fun enableHighRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val display: Display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display ?: return
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        }
        val modes = display.supportedModes
        if (modes.isEmpty()) return
        // Highest refresh rate available at the current (native) resolution.
        val current = display.mode
        val best = modes
            .filter {
                it.physicalWidth == current.physicalWidth &&
                    it.physicalHeight == current.physicalHeight
            }
            .maxByOrNull { it.refreshRate } ?: return
        if (best.refreshRate > current.refreshRate) {
            val params = window.attributes
            @Suppress("DEPRECATION")
            params.preferredDisplayModeId = best.modeId
            window.attributes = params
        }
    }
}

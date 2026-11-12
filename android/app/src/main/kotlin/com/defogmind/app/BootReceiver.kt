package com.defogmind.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            val prefs = context.getSharedPreferences(FocusMonitorService.PREFS_NAME, Context.MODE_PRIVATE)
            val adultTrackingEnabled = prefs.getBoolean(FocusMonitorService.KEY_ADULT_TRACKING_ENABLED, true)
            val isKidsActive = prefs.getBoolean(FocusMonitorService.KEY_KIDS_MODE_ACTIVE, false)
            if (!adultTrackingEnabled && !isKidsActive) return

            val serviceIntent = Intent(context, FocusMonitorService::class.java).apply {
                action = FocusMonitorService.ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }
    }
}


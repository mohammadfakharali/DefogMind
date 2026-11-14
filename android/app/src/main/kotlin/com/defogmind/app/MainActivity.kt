package com.defogmind.app

import android.app.AppOpsManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.defogmind/platform"
    private val NOTIFICATION_PERMISSION_REQUEST_CODE = 2001
    private val bgExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        FocusMonitorService.isMainActivityVisible = true
        super.onCreate(savedInstanceState)
    }

    override fun onStart() {
        super.onStart()
        FocusMonitorService.isMainActivityVisible = true
    }

    override fun onResume() {
        super.onResume()
        FocusMonitorService.isMainActivityVisible = true
    }

    override fun onStop() {
        super.onStop()
        FocusMonitorService.isMainActivityVisible = false
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkUsagePermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "requestUsagePermission" -> {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                    result.success(true)
                }
                "checkOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(Settings.canDrawOverlays(this))
                    } else {
                        result.success(true)
                    }
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        ).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                    }
                    result.success(true)
                }
                "checkNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            android.Manifest.permission.POST_NOTIFICATIONS
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    } else {
                        result.success(true)
                    }
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                            NOTIFICATION_PERMISSION_REQUEST_CODE
                        )
                    }
                    result.success(true)
                }
                "startFocusService" -> {
                    try {
                        val mode = call.argument<Int>("mode") ?: 1
                        val adultTrackingEnabled = call.argument<Boolean>("adultTrackingEnabled") ?: true
                        val duration = call.argument<Int>("passDuration") ?: 300
                        val limit = call.argument<Int>("dailyLimit") ?: 60
                        val packages = call.argument<List<String>>("packages") ?: emptyList()

                        saveServiceConfig(mode, adultTrackingEnabled, duration, limit, packages)
                        val prefs = getSharedPreferences(FocusMonitorService.PREFS_NAME, Context.MODE_PRIVATE)
                        val isKidsActive = prefs.getBoolean(FocusMonitorService.KEY_KIDS_MODE_ACTIVE, false)
                        if (adultTrackingEnabled || isKidsActive) {
                            val serviceIntent = Intent(this, FocusMonitorService::class.java).apply {
                                action = FocusMonitorService.ACTION_START
                                putExtra("EXTRA_MODE", mode)
                                putExtra("EXTRA_ADULT_TRACKING_ENABLED", adultTrackingEnabled)
                                putExtra("EXTRA_DURATION", duration)
                                putExtra("EXTRA_LIMIT", limit)
                                putStringArrayListExtra("EXTRA_PACKAGES", ArrayList(packages))
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(serviceIntent)
                            } else {
                                startService(serviceIntent)
                            }
                        } else if (FocusMonitorService.isServiceRunning) {
                            val stopIntent = Intent(this, FocusMonitorService::class.java).apply {
                                action = FocusMonitorService.ACTION_STOP
                            }
                            startService(stopIntent)
                        }
                        try {
                            DefogMindWidgetUpdater.updateWidgets(this)
                        } catch (_: Exception) {}
                        result.success(true)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.success(false)
                    }
                }
                "stopFocusService" -> {
                    try {
                        val serviceIntent = Intent(this, FocusMonitorService::class.java).apply {
                            action = FocusMonitorService.ACTION_STOP
                        }
                        startService(serviceIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.success(false)
                    }
                }
                "updateServiceConfig" -> {
                    try {
                        val mode = call.argument<Int>("mode") ?: 1
                        val adultTrackingEnabled = call.argument<Boolean>("adultTrackingEnabled") ?: true
                        val duration = call.argument<Int>("passDuration") ?: 300
                        val limit = call.argument<Int>("dailyLimit") ?: 60
                        val packages = call.argument<List<String>>("packages") ?: emptyList()

                        saveServiceConfig(mode, adultTrackingEnabled, duration, limit, packages)
                        val prefs = getSharedPreferences(FocusMonitorService.PREFS_NAME, Context.MODE_PRIVATE)
                        val isKidsActive = prefs.getBoolean(FocusMonitorService.KEY_KIDS_MODE_ACTIVE, false)
                        if (!adultTrackingEnabled && !isKidsActive) {
                            if (FocusMonitorService.isServiceRunning) {
                                val stopIntent = Intent(this, FocusMonitorService::class.java).apply {
                                    action = FocusMonitorService.ACTION_STOP
                                }
                                startService(stopIntent)
                            }
                        } else {
                            val serviceIntent = Intent(this, FocusMonitorService::class.java).apply {
                                action = if (FocusMonitorService.isServiceRunning) {
                                    FocusMonitorService.ACTION_UPDATE_CONFIG
                                } else {
                                    FocusMonitorService.ACTION_START
                                }
                                putExtra("EXTRA_MODE", mode)
                                putExtra("EXTRA_ADULT_TRACKING_ENABLED", adultTrackingEnabled)
                                putExtra("EXTRA_DURATION", duration)
                                putExtra("EXTRA_LIMIT", limit)
                                putStringArrayListExtra("EXTRA_PACKAGES", ArrayList(packages))
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !FocusMonitorService.isServiceRunning) {
                                startForegroundService(serviceIntent)
                            } else {
                                startService(serviceIntent)
                            }
                        }
                        try {
                            DefogMindWidgetUpdater.updateWidgets(this)
                        } catch (_: Exception) {}
                        result.success(true)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.success(false)
                    }
                }
                "checkBatteryExemption" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    } else {
                        result.success(true)
                    }
                }
                "requestBatteryExemption" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                        } catch (e: Exception) {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                        }
                    }
                    result.success(true)
                }
                "openAutoStartSettings" -> {
                    val intents = arrayOf(
                        Intent().setComponent(android.content.ComponentName("com.transsion.phonemaster", "com.transsion.phonemaster.autostart.AutoStartActivity")),
                        Intent().setComponent(android.content.ComponentName("com.transsion.powerchecker", "com.transsion.powerchecker.PowerMarathonActivity")),
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                        }
                    )
                    var opened = false
                    for (intent in intents) {
                        try {
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            opened = true
                            break
                        } catch (e: Exception) {
                            // try next intent
                        }
                    }
                    result.success(opened)
                }
                "triggerOxygenPass" -> {
                    val duration = call.argument<Int>("durationSeconds") ?: 300
                    val serviceIntent = Intent(this, FocusMonitorService::class.java).apply {
                        action = FocusMonitorService.ACTION_TRIGGER_PASS
                        putExtra("EXTRA_DURATION", duration)
                    }
                    startService(serviceIntent)
                    result.success(true)
                }
                "getDailyUsageStats" -> {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    bgExecutor.execute {
                        try {
                            val stats = getTodayUsageStats(packages)
                            runOnUiThread { result.success(stats) }
                        } catch (e: Exception) {
                            runOnUiThread { result.success(emptyMap<String, Long>()) }
                        }
                    }
                }
                "getInstalledApps" -> {
                    bgExecutor.execute {
                        try {
                            val apps = getInstalledAppsList()
                            runOnUiThread { result.success(apps) }
                        } catch (e: Exception) {
                            runOnUiThread { result.success(emptyList<Map<String, String>>()) }
                        }
                    }
                }
                "getCurrentBrainFog" -> {
                    val prefs = getSharedPreferences(FocusMonitorService.PREFS_NAME, Context.MODE_PRIVATE)
                    val fog = if (FocusMonitorService.isServiceRunning) {
                        FocusMonitorService.liveNetBrainFogPercent
                    } else {
                        Math.round(prefs.getFloat(FocusMonitorService.KEY_CENTRAL_AWARENESS_FOG, 0f)).toInt()
                    }
                    result.success(fog)
                }
                "getBrainFogStatus" -> {
                    val prefs = getSharedPreferences(FocusMonitorService.PREFS_NAME, Context.MODE_PRIVATE)
                    val fog = if (FocusMonitorService.isServiceRunning) {
                        FocusMonitorService.liveNetBrainFogPercent
                    } else {
                        Math.round(prefs.getFloat(FocusMonitorService.KEY_CENTRAL_AWARENESS_FOG, 0f)).toInt()
                    }
                    val word = when {
                        fog <= 30 -> "Fresh"
                        fog <= 60 -> "Tired"
                        fog <= 90 -> "Heavy"
                        else -> "Overloaded"
                    }
                    val mins = FocusMonitorService.liveTodaySocialMinutes
                    result.success(mapOf(
                        "percentage" to fog,
                        "statusWord" to word,
                        "totalSocialMinutes" to mins
                    ))
                }
                "setKidsMode" -> {
                    try {
                        val active = call.argument<Boolean>("active") ?: false
                        val limitMinutes = call.argument<Int>("limitMinutes") ?: 30
                        val remainingSeconds = call.argument<Int>("remainingSeconds") ?: (limitMinutes * 60)
                        val allowedPackages = call.argument<List<String>>("allowedPackages") ?: emptyList()

                        val prefs = getSharedPreferences(FocusMonitorService.PREFS_NAME, Context.MODE_PRIVATE)
                        prefs.edit().apply {
                            putBoolean(FocusMonitorService.KEY_KIDS_MODE_ACTIVE, active)
                            putInt(FocusMonitorService.KEY_KIDS_LIMIT_MINUTES, limitMinutes)
                            putInt(FocusMonitorService.KEY_KIDS_REMAINING_SECONDS, remainingSeconds)
                            putStringSet(FocusMonitorService.KEY_KIDS_ALLOWED_PACKAGES, allowedPackages.toSet())
                            commit()
                        }

                        FocusMonitorService.isKidsModeActive = active
                        FocusMonitorService.liveKidsLimitMinutes = limitMinutes
                        FocusMonitorService.liveKidsRemainingSeconds = remainingSeconds

                        val serviceIntent = Intent(this, FocusMonitorService::class.java).apply {
                            action = FocusMonitorService.ACTION_UPDATE_KIDS_MODE
                            putExtra("EXTRA_KIDS_ACTIVE", active)
                            putExtra("EXTRA_KIDS_LIMIT_MINUTES", limitMinutes)
                            putExtra("EXTRA_KIDS_REMAINING_SECONDS", remainingSeconds)
                            putStringArrayListExtra("EXTRA_KIDS_ALLOWED_PACKAGES", ArrayList(allowedPackages))
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !FocusMonitorService.isServiceRunning) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        try {
                            DefogMindWidgetUpdater.updateWidgets(this)
                        } catch (_: Exception) {}
                        result.success(true)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.success(false)
                    }
                }
                "getKidsModeStatus" -> {
                    val prefs = getSharedPreferences(FocusMonitorService.PREFS_NAME, Context.MODE_PRIVATE)
                    val isActive = if (FocusMonitorService.isServiceRunning) {
                        FocusMonitorService.isKidsModeActive
                    } else {
                        prefs.getBoolean(FocusMonitorService.KEY_KIDS_MODE_ACTIVE, false)
                    }
                    val limitMins = prefs.getInt(FocusMonitorService.KEY_KIDS_LIMIT_MINUTES, 30)
                    val remainingSecs = if (FocusMonitorService.isServiceRunning && isActive) {
                        FocusMonitorService.liveKidsRemainingSeconds
                    } else {
                        prefs.getInt(FocusMonitorService.KEY_KIDS_REMAINING_SECONDS, limitMins * 60)
                    }
                    val allowedPkgs = prefs.getStringSet(FocusMonitorService.KEY_KIDS_ALLOWED_PACKAGES, emptySet())?.toList() ?: emptyList()

                    val todayKey = java.text.SimpleDateFormat("yyyyMMdd", java.util.Locale.US).format(java.util.Date())
                    val kidsDay = prefs.getString(FocusMonitorService.KEY_KIDS_USAGE_DAY, "") ?: ""
                    val kidsUsageMap = mutableMapOf<String, Long>()
                    if (kidsDay == todayKey) {
                        val trackedKidsSet = prefs.getStringSet(FocusMonitorService.KEY_KIDS_TRACKED_PACKAGES, emptySet()) ?: emptySet()
                        for (pkg in trackedKidsSet) {
                            val ms = prefs.getLong(FocusMonitorService.KEY_KIDS_USAGE_PREFIX + pkg, 0L)
                            if (ms > 0L) {
                                kidsUsageMap[pkg] = ms
                            }
                        }
                    }

                    result.success(mapOf(
                        "isActive" to isActive,
                        "limitMinutes" to limitMins,
                        "remainingSeconds" to remainingSecs,
                        "allowedPackages" to allowedPkgs,
                        "kidsUsageMillis" to kidsUsageMap
                    ))
                }
                "isPinWidgetSupported" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val appWidgetManager = getSystemService(android.appwidget.AppWidgetManager::class.java)
                        result.success(appWidgetManager?.isRequestPinAppWidgetSupported ?: false)
                    } else {
                        result.success(false)
                    }
                }
                "requestPinWidget" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val appWidgetManager = getSystemService(android.appwidget.AppWidgetManager::class.java)
                            if (appWidgetManager?.isRequestPinAppWidgetSupported == true) {
                                val provider = android.content.ComponentName(this, DefogMindWidgetProvider::class.java)
                                appWidgetManager.requestPinAppWidget(provider, null, null)
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.success(false)
                    }
                }
                "updateHomeScreenWidgets" -> {
                    try {
                        DefogMindWidgetUpdater.updateWidgets(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun saveServiceConfig(mode: Int, adultTrackingEnabled: Boolean, duration: Int, limit: Int, packages: List<String>) {
        val prefs = getSharedPreferences(FocusMonitorService.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().apply {
            putInt(FocusMonitorService.KEY_FOCUS_MODE, mode)
            putBoolean(FocusMonitorService.KEY_ADULT_TRACKING_ENABLED, adultTrackingEnabled)
            putInt(FocusMonitorService.KEY_OXYGEN_PASS_DURATION, duration)
            putInt(FocusMonitorService.KEY_DAILY_LIMIT_MINUTES, limit)
            if (packages.isNotEmpty()) {
                putStringSet(FocusMonitorService.KEY_MONITORED_PACKAGES, packages.toSet())
            }
            apply()
        }
    }

    private fun getTodayUsageStats(monitoredPackages: List<String>): Map<String, Long> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        return FocusMonitorService.queryExactTodayUsageMap(usageStatsManager, monitoredPackages.toSet())
    }

    private fun getInstalledAppsList(): List<Map<String, String>> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val apps = pm.queryIntentActivities(intent, 0)
        val resultList = mutableListOf<Map<String, String>>()

        for (resolveInfo in apps) {
            val appInfo = resolveInfo.activityInfo.applicationInfo
            // Exclude our own package
            if (appInfo.packageName != packageName) {
                val appName = pm.getApplicationLabel(appInfo).toString()
                resultList.add(
                    mapOf(
                        "packageName" to appInfo.packageName,
                        "appName" to appName
                    )
                )
            }
        }
        return resultList.sortedBy { it["appName"]?.lowercase() }
    }
}

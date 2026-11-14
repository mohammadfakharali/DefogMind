package com.defogmind.app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

class FocusMonitorService : Service() {

    companion object {
        const val CHANNEL_ID = "defogmind_focus_monitor"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START = "com.defogmind.START_SERVICE"
        const val ACTION_STOP = "com.defogmind.STOP_SERVICE"
        const val ACTION_UPDATE_CONFIG = "com.defogmind.UPDATE_CONFIG"
        const val ACTION_CLAIM_OXYGEN_PASS = "com.defogmind.CLAIM_OXYGEN_PASS"
        const val ACTION_TRIGGER_PASS = "com.defogmind.TRIGGER_PASS"
        const val ACTION_UPDATE_KIDS_MODE = "com.defogmind.UPDATE_KIDS_MODE"

        const val PREFS_NAME = "DefogMindMonitorPrefs"
        const val KEY_MONITORED_PACKAGES = "monitored_packages"
        const val KEY_FOCUS_MODE = "focus_mode" // 0: Awareness, 1: Limit Mode
        const val KEY_ADULT_TRACKING_ENABLED = "adult_tracking_enabled"
        const val KEY_OXYGEN_PASS_DURATION = "oxygen_pass_duration_seconds" // 120, 300, 600
        const val KEY_DAILY_LIMIT_MINUTES = "daily_limit_minutes"
        const val KEY_CENTRAL_AWARENESS_FOG = "central_awareness_fog_percent"

        // Kids Mode Keys
        const val KEY_KIDS_MODE_ACTIVE = "kids_mode_active"
        const val KEY_KIDS_ALLOWED_PACKAGES = "kids_allowed_packages"
        const val KEY_KIDS_LIMIT_MINUTES = "kids_limit_minutes"
        const val KEY_KIDS_REMAINING_SECONDS = "kids_remaining_seconds"
        const val KEY_KIDS_USAGE_DAY = "kids_usage_day"
        const val KEY_KIDS_TRACKED_PACKAGES = "kids_tracked_packages"
        const val KEY_KIDS_USAGE_PREFIX = "kids_pkg_ms_"

        @Volatile
        var isServiceRunning: Boolean = false

        @Volatile
        var isMainActivityVisible: Boolean = false

        @Volatile
        var liveNetBrainFogPercent: Int = 0

        @Volatile
        var liveTodaySocialMinutes: Int = 0

        @Volatile
        var liveStatusWord: String = "Fresh"

        @Volatile
        var isKidsModeActive: Boolean = false

        @Volatile
        var liveKidsRemainingSeconds: Int = 0

        @Volatile
        var liveKidsLimitMinutes: Int = 30

        @Volatile
        private var cachedAllUsageMap: Map<String, Long> = emptyMap()

        @Volatile
        private var lastUsageMapCacheMs: Long = 0L

        /**
         * Calculates exact foreground usage (in milliseconds) per package strictly since 12:00:00 AM local midnight
         * using UsageEvents, preventing Android's INTERVAL_DAILY buckets from bleeding yesterday's minutes into today.
         * Cached for 10 seconds to prevent redundant 24-hour Binder scans across Service and MainActivity.
         */
        @Synchronized
        fun queryExactTodayUsageMap(
            usageStatsManager: UsageStatsManager,
            filterPackages: Set<String>
        ): Map<String, Long> {
            val nowMs = System.currentTimeMillis()
            if (cachedAllUsageMap.isNotEmpty() && (nowMs - lastUsageMapCacheMs) < 10000L) {
                if (filterPackages.isEmpty()) return cachedAllUsageMap
                return cachedAllUsageMap.filterKeys { filterPackages.contains(it) }
            }

            val calendar = java.util.Calendar.getInstance().apply {
                set(java.util.Calendar.HOUR_OF_DAY, 0)
                set(java.util.Calendar.MINUTE, 0)
                set(java.util.Calendar.SECOND, 0)
                set(java.util.Calendar.MILLISECOND, 0)
            }
            val midnightMs = calendar.timeInMillis
            if (nowMs <= midnightMs) return emptyMap()

            // Look back up to 2 hours before midnight ONLY to detect if an app was already open at 11:59 PM across midnight
            val queryStartMs = midnightMs - (2 * 60 * 60 * 1000L)
            val events = usageStatsManager.queryEvents(queryStartMs, nowMs)
            val event = UsageEvents.Event()

            val totalMap = mutableMapOf<String, Long>()
            val activeStartMap = mutableMapOf<String, Long>()

            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                val pkg = event.packageName ?: continue
                val time = event.timeStamp

                when (event.eventType) {
                    UsageEvents.Event.ACTIVITY_RESUMED -> {
                        if (!activeStartMap.containsKey(pkg)) {
                            activeStartMap[pkg] = time
                        }
                    }
                    UsageEvents.Event.ACTIVITY_PAUSED,
                    UsageEvents.Event.ACTIVITY_STOPPED -> {
                        val start = activeStartMap.remove(pkg)
                        if (start != null && time > midnightMs) {
                            val clampedStart = maxOf(start, midnightMs)
                            if (time > clampedStart) {
                                totalMap[pkg] = (totalMap[pkg] ?: 0L) + (time - clampedStart)
                            }
                        }
                    }
                    UsageEvents.Event.SCREEN_NON_INTERACTIVE,
                    UsageEvents.Event.KEYGUARD_SHOWN,
                    UsageEvents.Event.DEVICE_SHUTDOWN -> {
                        // Screen locked or turned off: close all currently open foreground sessions
                        val activeEntries = activeStartMap.entries.toList()
                        activeStartMap.clear()
                        if (time > midnightMs) {
                            for ((activePkg, start) in activeEntries) {
                                val clampedStart = maxOf(start, midnightMs)
                                if (time > clampedStart) {
                                    totalMap[activePkg] = (totalMap[activePkg] ?: 0L) + (time - clampedStart)
                                }
                            }
                        }
                    }
                }
            }

            // Close any session that is still actively open right now (up to nowMs)
            for ((activePkg, start) in activeStartMap) {
                val clampedStart = maxOf(start, midnightMs)
                if (nowMs > clampedStart) {
                    // Safety cap: if an event lacked a pause event from hours ago, only count if it is recent
                    if (nowMs - start <= 2 * 60 * 60 * 1000L) {
                        totalMap[activePkg] = (totalMap[activePkg] ?: 0L) + (nowMs - clampedStart)
                    }
                }
            }

            cachedAllUsageMap = totalMap
            lastUsageMapCacheMs = nowMs

            if (filterPackages.isEmpty()) return totalMap
            return totalMap.filterKeys { filterPackages.contains(it) }
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val monitorThread = android.os.HandlerThread("DefogMindMonitorBg").apply { start() }
    private val handler = Handler(monitorThread.looper)
    private var isMonitoring = false
    private lateinit var prefs: SharedPreferences
    private lateinit var usageStatsManager: UsageStatsManager
    private lateinit var windowManager: WindowManager

    // Configuration
    private var monitoredPackages = mutableSetOf(
        "com.instagram.android",
        "com.zhiliaoapp.musically",
        "com.google.android.youtube",
        "com.twitter.android",
        "com.facebook.katana",
        "com.snapchat.android",
        "com.reddit.frontpage"
    )
    private var focusMode = 1 // 0: Awareness, 1: Limit Mode
    private var adultTrackingEnabled = true
    private var passConfiguredDurationSeconds = 300 // Default 5 min
    private var dailyLimitMinutes = 60

    // Dual-Clock Bypass Engine
    private var isBypassActive = false
    private var bypassActiveRemainingSeconds = 0
    private var bypassWallClockExpiryMillis = 0L
    private val ABSOLUTE_WALL_CLOCK_CEILING_MS = 15 * 60 * 1000L // 15 mins ceiling
    private var lastWidgetUpdateTimestampMs: Long = 0L

    // Movable Floating HUD / Pill Overlay
    private var floatingPillView: View? = null
    private var floatingPillPrefixText: TextView? = null
    private var floatingPillBrainCharacter: BrainCharacterView? = null
    private var floatingPillSuffixText: TextView? = null
    private var pillLayoutParams: WindowManager.LayoutParams? = null
    private var hasUserMovedPill = false
    private var lastPillX = 0
    private var lastPillY = 0
    private var wakeLock: PowerManager.WakeLock? = null

    // Tracking state
    private var lastForegroundPackage: String = ""
    private var isTargetInForeground = false
    private var todaySocialMinutes = 0

    // Real-Time Foreground Usage Tracking & Centralized Awareness Fog Store
    private var wasTargetInForeground = false
    private var currentSessionStartMs = 0L
    private var currentSessionContinuousMs = 0L
    private var baseHistoricalSocialMs = 0L
    private var cachedTodaySocialMs = 0L
    private var cachedDayKey = ""
    private var lastSocialExitTimestampMs = 0L
    private var centralAwarenessFog: Double = 0.0
    private var currentNetBrainFogPercent = 0
    private var lastDetoxMilestoneShown = 0
    private var detoxPeekExpiryMs = 0L
    private var isFadingOutPill = false
    private var lastFullUsageQueryMs = 0L

    // Kids Mode Sandbox State
    private var kidsAllowedPackages = mutableSetOf<String>()
    private var kidsLimitMinutes = 30
    private var kidsRemainingSeconds = 1800
    private var kidsTodayUsageMsMap = mutableMapOf<String, Long>()
    private var cachedLauncherPackages = mutableSetOf<String>()
    private var lastLauncherQueryMs = 0L

    private val bypassReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_CLAIM_OXYGEN_PASS, ACTION_TRIGGER_PASS -> {
                    val duration = intent.getIntExtra("EXTRA_DURATION", passConfiguredDurationSeconds)
                    activateBypass(duration)
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        loadSavedConfig()
        createNotificationChannel()

        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "DefogMind:MonitorWakeLock")
            wakeLock?.acquire(24 * 60 * 60 * 1000L) // 24hr safe ceiling
        } catch (e: Exception) {
            // ignore
        }

        val filter = IntentFilter().apply {
            addAction(ACTION_CLAIM_OXYGEN_PASS)
            addAction(ACTION_TRIGGER_PASS)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(bypassReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(bypassReceiver, filter)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                cancelServiceRestart()
                stopMonitoring()
                stopForeground(true)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_UPDATE_CONFIG -> {
                loadSavedConfig()
                applyIntentConfig(intent)
                if (!adultTrackingEnabled && !isKidsModeActive) {
                    cancelServiceRestart()
                    stopMonitoring()
                    stopForeground(true)
                    stopSelf()
                    return START_NOT_STICKY
                }
            }
            ACTION_UPDATE_KIDS_MODE -> {
                loadSavedConfig()
                applyKidsModeIntent(intent)
                if (!adultTrackingEnabled && !isKidsModeActive) {
                    cancelServiceRestart()
                    stopMonitoring()
                    stopForeground(true)
                    stopSelf()
                    return START_NOT_STICKY
                } else {
                    startForegroundServiceCompat()
                    startMonitoring()
                    scheduleServiceRestart(4000L)
                }
            }
            ACTION_TRIGGER_PASS -> {
                val duration = intent.getIntExtra("EXTRA_DURATION", passConfiguredDurationSeconds)
                activateBypass(duration)
            }
            else -> {
                loadSavedConfig()
                applyIntentConfig(intent)
                applyKidsModeIntent(intent)
                if (!adultTrackingEnabled && !isKidsModeActive) {
                    cancelServiceRestart()
                    stopMonitoring()
                    stopForeground(true)
                    stopSelf()
                    return START_NOT_STICKY
                }
                startForegroundServiceCompat()
                startMonitoring()
                scheduleServiceRestart(4000L)
            }
        }
        return START_STICKY
    }

    private fun applyIntentConfig(intent: Intent?) {
        if (intent == null) return
        if (intent.hasExtra("EXTRA_MODE")) {
            focusMode = intent.getIntExtra("EXTRA_MODE", focusMode)
        }
        if (intent.hasExtra("EXTRA_ADULT_TRACKING_ENABLED")) {
            adultTrackingEnabled = intent.getBooleanExtra("EXTRA_ADULT_TRACKING_ENABLED", adultTrackingEnabled)
            if (!adultTrackingEnabled && !isKidsModeActive) {
                hideFloatingPill()
            }
        }
        if (intent.hasExtra("EXTRA_DURATION")) {
            passConfiguredDurationSeconds = intent.getIntExtra("EXTRA_DURATION", passConfiguredDurationSeconds)
        }
        if (intent.hasExtra("EXTRA_LIMIT")) {
            dailyLimitMinutes = intent.getIntExtra("EXTRA_LIMIT", dailyLimitMinutes)
        }
        val pkgs = intent.getStringArrayListExtra("EXTRA_PACKAGES")
        if (pkgs != null && pkgs.isNotEmpty()) {
            monitoredPackages.clear()
            monitoredPackages.addAll(pkgs)
        }
    }

    private fun applyKidsModeIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.hasExtra("EXTRA_KIDS_ACTIVE")) {
            val active = intent.getBooleanExtra("EXTRA_KIDS_ACTIVE", false)
            isKidsModeActive = active
            if (intent.hasExtra("EXTRA_KIDS_LIMIT_MINUTES")) {
                kidsLimitMinutes = intent.getIntExtra("EXTRA_KIDS_LIMIT_MINUTES", kidsLimitMinutes)
                liveKidsLimitMinutes = kidsLimitMinutes
            }
            if (intent.hasExtra("EXTRA_KIDS_REMAINING_SECONDS")) {
                kidsRemainingSeconds = intent.getIntExtra("EXTRA_KIDS_REMAINING_SECONDS", kidsRemainingSeconds)
                liveKidsRemainingSeconds = kidsRemainingSeconds
            }
            val allowed = intent.getStringArrayListExtra("EXTRA_KIDS_ALLOWED_PACKAGES")
            if (allowed != null) {
                kidsAllowedPackages.clear()
                kidsAllowedPackages.addAll(allowed)
            }
            if (!active) {
                hideFloatingPill()
            }
        }
    }

    // Keep service alive if swiped from recent apps or background killed by OS
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        scheduleServiceRestart(500L)
    }

    private fun scheduleServiceRestart(delayMillis: Long = 500L) {
        val restartServiceIntent = Intent(applicationContext, FocusMonitorService::class.java).apply {
            action = ACTION_START
        }
        val restartServicePendingIntent = PendingIntent.getService(
            applicationContext,
            1,
            restartServiceIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmService = getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        alarmService.set(
            AlarmManager.ELAPSED_REALTIME,
            SystemClock.elapsedRealtime() + delayMillis,
            restartServicePendingIntent
        )
    }

    private fun cancelServiceRestart() {
        val restartServiceIntent = Intent(applicationContext, FocusMonitorService::class.java).apply {
            action = ACTION_START
        }
        val pendingIntent = PendingIntent.getService(
            applicationContext,
            1,
            restartServiceIntent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pendingIntent != null) {
            val alarmService = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            alarmService?.cancel(pendingIntent)
        }
    }

    private fun getTodayDateKey(): String {
        val sdf = java.text.SimpleDateFormat("yyyyMMdd", java.util.Locale.US)
        return sdf.format(java.util.Date())
    }

    private fun loadSavedConfig() {
        focusMode = prefs.getInt(KEY_FOCUS_MODE, 1)
        adultTrackingEnabled = prefs.getBoolean(KEY_ADULT_TRACKING_ENABLED, true)
        passConfiguredDurationSeconds = prefs.getInt(KEY_OXYGEN_PASS_DURATION, 300)
        dailyLimitMinutes = prefs.getInt(KEY_DAILY_LIMIT_MINUTES, 60)
        val savedPackages = prefs.getStringSet(KEY_MONITORED_PACKAGES, null)
        if (savedPackages != null && savedPackages.isNotEmpty()) {
            monitoredPackages.clear()
            monitoredPackages.addAll(savedPackages)
        }
        cachedDayKey = prefs.getString("KEY_TRACKED_DAY", "") ?: ""
        cachedTodaySocialMs = prefs.getLong("KEY_TRACKED_MS", 0L)
        lastSocialExitTimestampMs = prefs.getLong("KEY_LAST_SOCIAL_EXIT_MS", 0L)
        currentSessionContinuousMs = prefs.getLong("KEY_SESSION_CONTINUOUS_MS", 0L)
        centralAwarenessFog = prefs.getFloat(KEY_CENTRAL_AWARENESS_FOG, 0f).toDouble()
        currentNetBrainFogPercent = Math.round(centralAwarenessFog).toInt()
        liveNetBrainFogPercent = currentNetBrainFogPercent
        liveStatusWord = getAwarenessStatusWord(currentNetBrainFogPercent)

        // Load Kids Mode config & today's kids usage map
        isKidsModeActive = prefs.getBoolean(KEY_KIDS_MODE_ACTIVE, false)
        kidsLimitMinutes = prefs.getInt(KEY_KIDS_LIMIT_MINUTES, 30)
        kidsRemainingSeconds = prefs.getInt(KEY_KIDS_REMAINING_SECONDS, kidsLimitMinutes * 60)
        liveKidsLimitMinutes = kidsLimitMinutes
        liveKidsRemainingSeconds = kidsRemainingSeconds
        val savedKidsAllowed = prefs.getStringSet(KEY_KIDS_ALLOWED_PACKAGES, null)
        kidsAllowedPackages.clear()
        if (savedKidsAllowed != null) {
            kidsAllowedPackages.addAll(savedKidsAllowed)
        }

        val todayKey = getTodayDateKey()
        val kidsDay = prefs.getString(KEY_KIDS_USAGE_DAY, "") ?: ""
        kidsTodayUsageMsMap.clear()
        if (kidsDay == todayKey) {
            val trackedKidsSet = prefs.getStringSet(KEY_KIDS_TRACKED_PACKAGES, emptySet()) ?: emptySet()
            for (pkg in trackedKidsSet) {
                val ms = prefs.getLong(KEY_KIDS_USAGE_PREFIX + pkg, 0L)
                if (ms > 0L) {
                    kidsTodayUsageMsMap[pkg] = ms
                }
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "DefogMind Focus Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors foreground screen time and enforces digital wellbeing limits."
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(statusText: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val largeIcon = try {
            BitmapFactory.decodeResource(resources, R.drawable.ic_launcher_splash)
        } catch (_: Exception) {
            null
        }

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("DefogMind Focus Monitor: Active")
            .setContentText(statusText)
            .setSmallIcon(R.drawable.ic_brain)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pendingIntent)

        if (largeIcon != null) {
            builder.setLargeIcon(largeIcon)
        }

        return builder.build()
    }

    private fun startForegroundServiceCompat() {
        val notification = buildNotification("Focus monitor active • Tap to open dashboard")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun startMonitoring() {
        if (isMonitoring) return
        isMonitoring = true
        isServiceRunning = true
        handler.post(monitorRunnable)
    }

    private fun stopMonitoring() {
        isMonitoring = false
        isServiceRunning = false
        handler.removeCallbacks(monitorRunnable)
        hideFloatingPill()
    }

    private val monitorRunnable = object : Runnable {
        private var keepAliveTick = 0

        override fun run() {
            if (!isMonitoring) return
            try {
                checkForegroundAppAndEnforce()
                keepAliveTick++
                if (keepAliveTick >= 2) {
                    keepAliveTick = 0
                    scheduleServiceRestart(4000L)
                }

                val now = System.currentTimeMillis()
                if (now - lastWidgetUpdateTimestampMs >= 15000L) {
                    lastWidgetUpdateTimestampMs = now
                    DefogMindWidgetUpdater.updateWidgets(this@FocusMonitorService)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
            handler.postDelayed(this, 1000)
        }
    }

    private fun checkForegroundAppAndEnforce() {
        if (isMainActivityVisible) {
            lastForegroundPackage = packageName
        } else {
            val currentFgPackage = getForegroundPackageName()
            if (currentFgPackage.isNotEmpty()) {
                lastForegroundPackage = currentFgPackage
            }
        }

        val isDefogMindInForeground = isMainActivityVisible || (lastForegroundPackage == packageName)
        isTargetInForeground = !isDefogMindInForeground && monitoredPackages.contains(lastForegroundPackage)

        // Day transition check (resets everything cleanly at midnight or on fresh install)
        val todayKey = getTodayDateKey()
        if (cachedDayKey != todayKey) {
            cachedDayKey = todayKey
            cachedTodaySocialMs = 0L
            baseHistoricalSocialMs = 0L
            lastSocialExitTimestampMs = 0L
            currentSessionContinuousMs = 0L
            centralAwarenessFog = 0.0
            currentNetBrainFogPercent = 0
            liveNetBrainFogPercent = 0
            liveStatusWord = "Fresh"
            kidsTodayUsageMsMap.clear()
            prefs.edit()
                .putString("KEY_TRACKED_DAY", todayKey)
                .putLong("KEY_TRACKED_MS", 0L)
                .putLong("KEY_LAST_SOCIAL_EXIT_MS", 0L)
                .putLong("KEY_SESSION_CONTINUOUS_MS", 0L)
                .putFloat(KEY_CENTRAL_AWARENESS_FOG, 0f)
                .putInt("KEY_LAST_NET_FOG", 0)
                .putString(KEY_KIDS_USAGE_DAY, todayKey)
                .putStringSet(KEY_KIDS_TRACKED_PACKAGES, emptySet())
                .apply()
        }

        val now = System.currentTimeMillis()

        // ============================================================
        // KIDS MODE SANDBOX ENFORCEMENT (Complete Isolation from Adult)
        // ============================================================
        if (isKidsModeActive) {
            wasTargetInForeground = false

            // 1. Adult Brain Fog continues recovering naturally (-1% per 3 minutes) while Kids Mode is active
            if (centralAwarenessFog > 0.0) {
                val recoveryPerSecond = 1.0 / 180.0
                centralAwarenessFog = maxOf(0.0, centralAwarenessFog - recoveryPerSecond)
                currentNetBrainFogPercent = Math.round(centralAwarenessFog).toInt()
                liveNetBrainFogPercent = currentNetBrainFogPercent
                liveStatusWord = getAwarenessStatusWord(currentNetBrainFogPercent)
                prefs.edit()
                    .putFloat(KEY_CENTRAL_AWARENESS_FOG, centralAwarenessFog.toFloat())
                    .putInt("KEY_LAST_NET_FOG", currentNetBrainFogPercent)
                    .apply()
            }

            // 2. Check if foreground package is a whitelisted system / launcher / emergency / DefogMind package
            val isWhitelistedSystem = isSystemOrLauncherWhitelisted(lastForegroundPackage)
            if (isWhitelistedSystem) {
                hideFloatingPill()
                return
            }

            // 3. Record Kids Mode app usage separately so Adult usage & limit are never affected
            if (lastForegroundPackage.isNotEmpty()) {
                val updatedKidsMs = (kidsTodayUsageMsMap[lastForegroundPackage] ?: 0L) + 1000L
                kidsTodayUsageMsMap[lastForegroundPackage] = updatedKidsMs
                val trackedSet = HashSet(kidsTodayUsageMsMap.keys)
                prefs.edit()
                    .putString(KEY_KIDS_USAGE_DAY, todayKey)
                    .putStringSet(KEY_KIDS_TRACKED_PACKAGES, trackedSet)
                    .putLong(KEY_KIDS_USAGE_PREFIX + lastForegroundPackage, updatedKidsMs)
                    .apply()
            }

            // 4. Enforce Allowed Apps & Session Countdown
            if (kidsAllowedPackages.contains(lastForegroundPackage)) {
                if (kidsRemainingSeconds > 0) {
                    kidsRemainingSeconds--
                    liveKidsRemainingSeconds = kidsRemainingSeconds
                    prefs.edit()
                        .putInt(KEY_KIDS_REMAINING_SECONDS, kidsRemainingSeconds)
                        .apply()

                    val pillColor = if (kidsRemainingSeconds <= 300) Color.parseColor("#F59E0B") else Color.parseColor("#06B6D4")
                    showOrUpdateFloatingPill(formatKidsTimerText(kidsRemainingSeconds), false, "", pillColor)

                    if (kidsRemainingSeconds <= 0) {
                        hideFloatingPill()
                        triggerKidsBlockingOverlay(lastForegroundPackage, "TIME_UP")
                    }
                } else {
                    hideFloatingPill()
                    triggerKidsBlockingOverlay(lastForegroundPackage, "TIME_UP")
                }
            } else {
                // App is NOT in kidsAllowedPackages -> Immediately block!
                hideFloatingPill()
                triggerKidsBlockingOverlay(lastForegroundPackage, "APP_LOCKED")
            }
            return
        }

        // If Adult Focus Tracking is paused/disabled and Kids Mode is not active, stop adult enforcement & pill
        if (!adultTrackingEnabled) {
            wasTargetInForeground = false
            detoxPeekExpiryMs = 0L
            hideFloatingPill()
            cancelServiceRestart()
            stopMonitoring()
            mainHandler.post {
                stopForeground(true)
                stopSelf()
            }
            return
        }

        // Real-Time Live Usage & Centralized Awareness Fog Engine
        // Only run the full 24-hour UsageEvents scan on app entry/exit or every 15 seconds;
        // add +1000ms live every second in between to eliminate main-thread Binder congestion!
        val transitionOccurred = (isTargetInForeground != wasTargetInForeground)
        if (transitionOccurred || lastFullUsageQueryMs == 0L || (now - lastFullUsageQueryMs) >= 15000L) {
            cachedTodaySocialMs = calculateTodaySocialMs()
            lastFullUsageQueryMs = now
        } else if (isTargetInForeground) {
            cachedTodaySocialMs += 1000L
        }
        todaySocialMinutes = (cachedTodaySocialMs / 60000).toInt()

        if (isTargetInForeground) {
            if (!wasTargetInForeground) {
                // User just entered a monitored app: trigger immediate 3-second peek in Limit Mode!
                wasTargetInForeground = true
                currentSessionStartMs = now
                lastSocialExitTimestampMs = 0L
                lastDetoxMilestoneShown = -1
            }

            // Increment active session duration by 1 second (1000ms)
            currentSessionContinuousMs += 1000L

            // Simple Linear Awareness Mode Fatigue Rate:
            // Increase: +1% per 1 minute of active usage (+1.0 / 60.0 per second)
            val gainPerSecond = 1.0 / 60.0
            centralAwarenessFog = minOf(100.0, centralAwarenessFog + gainPerSecond)
            currentNetBrainFogPercent = Math.round(centralAwarenessFog).toInt()
            liveNetBrainFogPercent = currentNetBrainFogPercent
            liveStatusWord = getAwarenessStatusWord(currentNetBrainFogPercent)
            liveTodaySocialMinutes = todaySocialMinutes

            prefs.edit()
                .putLong("KEY_TRACKED_MS", cachedTodaySocialMs)
                .putLong("KEY_SESSION_CONTINUOUS_MS", currentSessionContinuousMs)
                .putFloat(KEY_CENTRAL_AWARENESS_FOG, centralAwarenessFog.toFloat())
                .putInt("KEY_LAST_NET_FOG", currentNetBrainFogPercent)
                .putLong("KEY_LAST_SOCIAL_EXIT_MS", 0L)
                .apply()
        } else {
            if (wasTargetInForeground) {
                // User just exited the monitored app: break begins!
                lastSocialExitTimestampMs = now
                wasTargetInForeground = false

                prefs.edit()
                    .putLong("KEY_TRACKED_MS", cachedTodaySocialMs)
                    .putLong("KEY_LAST_SOCIAL_EXIT_MS", lastSocialExitTimestampMs)
                    .putLong("KEY_SESSION_CONTINUOUS_MS", currentSessionContinuousMs)
                    .putFloat(KEY_CENTRAL_AWARENESS_FOG, centralAwarenessFog.toFloat())
                    .putInt("KEY_LAST_NET_FOG", currentNetBrainFogPercent)
                    .apply()
            } else {
                // Real-time rest recovery while outside monitored apps (only if centralAwarenessFog > 0)
                if (centralAwarenessFog > 0.0) {
                    // Decrease: -1% per 3 minutes of rest (-1/3% per minute = 1.0 / 180.0 per second)
                    // Naturally reaches 0% from 100% in 300 minutes (5 hours)
                    val recoveryPerSecond = 1.0 / 180.0
                    centralAwarenessFog = maxOf(0.0, centralAwarenessFog - recoveryPerSecond)
                    prefs.edit()
                        .putFloat(KEY_CENTRAL_AWARENESS_FOG, centralAwarenessFog.toFloat())
                        .putInt("KEY_LAST_NET_FOG", Math.round(centralAwarenessFog).toInt())
                        .apply()
                }
            }

            currentNetBrainFogPercent = Math.round(centralAwarenessFog).toInt()
            liveNetBrainFogPercent = currentNetBrainFogPercent
            liveStatusWord = getAwarenessStatusWord(currentNetBrainFogPercent)
            liveTodaySocialMinutes = todaySocialMinutes
        }

        if (isBypassActive) {
            // 1. Absolute 15-Minute Wall-Clock Ceiling Check
            if (now >= bypassWallClockExpiryMillis) {
                expireBypass()
                return
            }

            // 2. Active Usage Clock: ONLY decrement while actively inside monitored social app
            if (isTargetInForeground) {
                bypassActiveRemainingSeconds--
                // Make sure pill is visible and showing active countdown
                showOrUpdateFloatingPill(formatBypassText(bypassActiveRemainingSeconds), false, "", Color.parseColor("#10B981"))

                if (bypassActiveRemainingSeconds <= 0) {
                    expireBypass()
                    return
                }
            } else {
                // When user left monitored app (e.g. Home screen): HIDE pill completely!
                hideFloatingPill()
            }
        } else {
            // No Bypass Active
            if (isTargetInForeground) {
                if (focusMode == 1) {
                    // Limit Mode: Trigger blocking shield if daily limit is reached
                    if (todaySocialMinutes >= dailyLimitMinutes) {
                        detoxPeekExpiryMs = 0L
                        hideFloatingPill()
                        triggerBlockingOverlay(lastForegroundPackage)
                    } else {
                        // Show 4-second fade-in/fade-out reminder immediately on entering app AND on every 1% change!
                        if (currentNetBrainFogPercent != lastDetoxMilestoneShown) {
                            lastDetoxMilestoneShown = currentNetBrainFogPercent
                            detoxPeekExpiryMs = now + 4000L // Show for 4 seconds
                        }

                        if (now < detoxPeekExpiryMs) {
                            val word = getAwarenessStatusWord(currentNetBrainFogPercent)
                            val statusColor = getAwarenessColor(currentNetBrainFogPercent)
                            showOrUpdateFloatingPill("", true, "$word • $currentNetBrainFogPercent% Fog", statusColor, animateFadeIn = true)
                        } else if (floatingPillView != null) {
                            fadeOutAndHideFloatingPill()
                        }
                    }
                } else {
                    // Awareness Mode (focusMode == 0): Show continuous movable awareness status pill inside tracked apps!
                    val word = getAwarenessStatusWord(currentNetBrainFogPercent)
                    val statusColor = getAwarenessColor(currentNetBrainFogPercent)
                    showOrUpdateFloatingPill("", true, "$word • $currentNetBrainFogPercent% Fog", statusColor)
                }
            } else {
                // Not in a monitored app -> Hide floating pill completely!
                detoxPeekExpiryMs = 0L
                hideFloatingPill()
            }
        }
    }

    private fun getForegroundPackageName(): String {
        // Fast check: if screen is off or keyguard (lock screen) is locked, no app is in foreground
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
            if (pm != null && !pm.isInteractive) {
                lastForegroundPackage = ""
                return ""
            }
            val km = getSystemService(Context.KEYGUARD_SERVICE) as? android.app.KeyguardManager
            if (km != null && km.isKeyguardLocked) {
                lastForegroundPackage = ""
                return ""
            }
        } catch (_: Exception) {}

        val now = System.currentTimeMillis()
        // 1. Quick 5-second slice for active live transitions
        var fgPackage = queryEventsForForeground(now - 5000, now)

        // 2. Only run deep 60s / 10m fallback queries on cold start when lastForegroundPackage is still unknown!
        // When user stays inside an app for >5s without switching, lastForegroundPackage is already preserved.
        if (fgPackage.isEmpty() && lastForegroundPackage.isEmpty()) {
            fgPackage = queryEventsForForeground(now - 60000, now)
            if (fgPackage.isEmpty()) {
                fgPackage = queryEventsForForeground(now - 600000, now)
            }
            if (fgPackage.isEmpty()) {
                val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, now - 600000, now)
                val mostRecent = stats?.filter { it.lastTimeUsed > 0 }?.maxByOrNull { it.lastTimeUsed }
                if (mostRecent != null && (now - mostRecent.lastTimeUsed) < 600000) {
                    fgPackage = mostRecent.packageName
                }
            }
        }

        return fgPackage
    }

    private fun queryEventsForForeground(startTime: Long, endTime: Long): String {
        val events = usageStatsManager.queryEvents(startTime, endTime)
        val event = UsageEvents.Event()
        var fgPackage = ""

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED,
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    fgPackage = event.packageName
                }
                UsageEvents.Event.KEYGUARD_SHOWN,
                UsageEvents.Event.SCREEN_NON_INTERACTIVE -> {
                    fgPackage = ""
                }
            }
        }
        return fgPackage
    }

    private fun calculateTodaySocialMs(): Long {
        val map = queryExactTodayUsageMap(usageStatsManager, monitoredPackages)
        var totalMs = 0L
        for ((pkg, ms) in map) {
            val kidsMs = kidsTodayUsageMsMap[pkg] ?: 0L
            val adultOnlyMs = maxOf(0L, ms - kidsMs)
            totalMs += adultOnlyMs
        }
        return totalMs
    }

    private fun isSystemOrLauncherWhitelisted(pkg: String): Boolean {
        if (pkg.isEmpty() || pkg == packageName) return true
        val lower = pkg.lowercase()

        // 1. Fast check for known OEM & AOSP Dialer, In-Call UI, Telecom, Emergency, Launcher, Keyboard, and System UI packages
        if (pkg == "com.android.systemui" ||
            pkg == "com.android.incallui" ||
            pkg == "com.google.android.dialer" ||
            pkg == "com.android.dialer" ||
            pkg == "com.sh.smart.caller" ||
            pkg == "com.transsion.smartcaller" ||
            pkg == "com.samsung.android.dialer" ||
            pkg == "com.samsung.android.incallui" ||
            pkg == "com.samsung.android.app.telephonyui" ||
            pkg == "com.oplus.dialer" ||
            pkg == "com.android.bbkphone" ||
            pkg == "com.android.contacts" ||
            pkg == "com.huawei.contacts" ||
            pkg == "com.android.server.telecom" ||
            pkg == "com.android.phone" ||
            pkg == "com.android.stk" ||
            pkg == "com.android.permissioncontroller" ||
            pkg == "com.google.android.permissioncontroller" ||
            pkg == "com.android.emergency" ||
            lower.contains("dialer") ||
            lower.contains("caller") ||
            lower.contains("incallui") ||
            lower.contains("telephony") ||
            lower.contains("telecom") ||
            lower.contains("phone") ||
            lower.contains("emergency") ||
            lower.contains("launcher") ||
            lower.contains("trebuchet") ||
            lower.contains("inputmethod") ||
            lower.contains("keyboard")
        ) {
            return true
        }

        // 2. Dynamic resolution of Home Launchers, Default Telecom Dialer, ACTION_DIAL handlers, and "Phone" labeled system apps
        val now = System.currentTimeMillis()
        if (cachedLauncherPackages.isEmpty() || (now - lastLauncherQueryMs) > 60000L) {
            lastLauncherQueryMs = now
            val resolvedSet = mutableSetOf<String>()

            // A. Default Home Screen Launchers
            try {
                val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                }
                for (info in packageManager.queryIntentActivities(homeIntent, 0)) {
                    info.activityInfo?.packageName?.let { if (it.isNotEmpty()) resolvedSet.add(it) }
                }
            } catch (_: Exception) {}

            // B. TelecomManager Default Dialer Package
            try {
                val telecom = getSystemService(Context.TELECOM_SERVICE) as? android.telecom.TelecomManager
                telecom?.defaultDialerPackage?.let { if (it.isNotEmpty()) resolvedSet.add(it) }
            } catch (_: Exception) {}

            // C. All installed Dialer handlers (ACTION_DIAL & tel: scheme)
            try {
                val dialIntents = listOf(
                    Intent(Intent.ACTION_DIAL),
                    Intent(Intent.ACTION_DIAL, android.net.Uri.parse("tel:")),
                    Intent(Intent.ACTION_VIEW, android.net.Uri.parse("tel:")),
                    Intent(Intent.ACTION_CALL_BUTTON)
                )
                for (dIntent in dialIntents) {
                    for (info in packageManager.queryIntentActivities(dIntent, 0)) {
                        info.activityInfo?.packageName?.let { if (it.isNotEmpty()) resolvedSet.add(it) }
                    }
                }
            } catch (_: Exception) {}

            cachedLauncherPackages.clear()
            cachedLauncherPackages.addAll(resolvedSet)
        }
        return cachedLauncherPackages.contains(pkg)
    }

    private fun formatKidsTimerText(seconds: Int): String {
        val mins = seconds / 60
        val secs = seconds % 60
        return String.format("🧸 Kids Time: %02d:%02d", mins, secs)
    }

    private fun triggerKidsBlockingOverlay(blockedPkg: String, reason: String) {
        val overlayIntent = Intent(this, OverlayActivity::class.java).apply {
            putExtra("EXTRA_BLOCKED_PACKAGE", blockedPkg)
            putExtra("EXTRA_KIDS_MODE", true)
            putExtra("EXTRA_KIDS_REASON", reason)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        startActivity(overlayIntent)
    }

    private fun getAwarenessStatusWord(fogPercent: Int): String {
        return when {
            fogPercent <= 30 -> "Fresh"
            fogPercent <= 60 -> "Tired"
            fogPercent <= 90 -> "Heavy"
            else -> "Overloaded"
        }
    }

    private fun getAwarenessColor(fogPercent: Int): Int {
        return when {
            fogPercent <= 30 -> Color.parseColor("#10B981") // Mint
            fogPercent <= 60 -> Color.parseColor("#F59E0B") // Amber
            fogPercent <= 90 -> Color.parseColor("#FB923C") // Orange
            else -> Color.parseColor("#EF4444")             // Glitch Red
        }
    }

    private fun triggerBlockingOverlay(blockedPkg: String) {
        val overlayIntent = Intent(this, OverlayActivity::class.java).apply {
            putExtra("EXTRA_BLOCKED_PACKAGE", blockedPkg)
            putExtra("EXTRA_DURATION", passConfiguredDurationSeconds)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        startActivity(overlayIntent)
    }

    private fun activateBypass(durationSeconds: Int) {
        isBypassActive = true
        bypassActiveRemainingSeconds = durationSeconds
        bypassWallClockExpiryMillis = System.currentTimeMillis() + ABSOLUTE_WALL_CLOCK_CEILING_MS
        if (isTargetInForeground) {
            showOrUpdateFloatingPill(formatBypassText(bypassActiveRemainingSeconds), false, "", Color.parseColor("#10B981"))
        }
    }

    private fun expireBypass() {
        isBypassActive = false
        bypassActiveRemainingSeconds = 0
        hideFloatingPill()

        if (isTargetInForeground && focusMode == 1) {
            triggerBlockingOverlay(lastForegroundPackage)
        }
    }

    private fun formatBypassText(seconds: Int): String {
        val m = seconds / 60
        val s = seconds % 60
        return String.format("⚡ Extra Unlock: %02d:%02d", m, s)
    }

    // --- Movable, Translucent Floating Pill with Tap-to-Open ---

    private fun showOrUpdateFloatingPill(
        prefix: String,
        showBrain: Boolean,
        suffix: String,
        accentColor: Int,
        animateFadeIn: Boolean = false
    ) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post {
                showOrUpdateFloatingPill(prefix, showBrain, suffix, accentColor, animateFadeIn)
            }
            return
        }
        if (!Settings.canDrawOverlays(this)) return

        isFadingOutPill = false

        if (floatingPillView == null) {
            val isDark = PassStorage.isDarkTheme(this)
            val pillBgColor = if (isDark) Color.parseColor("#D90B0F17") else Color.parseColor("#E6FFFFFF")
            val density = resources.displayMetrics.density
            val padH = (14 * density).toInt()
            val padV = (7 * density).toInt()
            val root = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(padH, padV, padH, padV)
                val shape = GradientDrawable().apply {
                    setColor(pillBgColor)
                    setStroke(2, accentColor)
                    cornerRadius = 40f * density
                }
                background = shape
                if (animateFadeIn) {
                    alpha = 0f
                }
            }

            val prefixView = TextView(this).apply {
                text = prefix
                setTextColor(accentColor)
                textSize = 13.5f
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                visibility = if (prefix.isNotEmpty()) View.VISIBLE else View.GONE
            }
            root.addView(prefixView)
            floatingPillPrefixText = prefixView

            val brainSize = (28 * density).toInt()
            val brainCharView = BrainCharacterView(this).apply {
                layoutParams = LinearLayout.LayoutParams(brainSize, brainSize).apply {
                    setMargins(if (prefix.isNotEmpty()) (6 * density).toInt() else 0, 0, (8 * density).toInt(), 0)
                }
                visibility = if (showBrain) View.VISIBLE else View.GONE
            }
            val currentTier = when {
                currentNetBrainFogPercent <= 30 -> 0
                currentNetBrainFogPercent <= 60 -> 1
                currentNetBrainFogPercent <= 90 -> 2
                else -> 3
            }
            brainCharView.updateTier(currentTier)
            root.addView(brainCharView)
            floatingPillBrainCharacter = brainCharView

            val suffixView = TextView(this).apply {
                text = suffix
                setTextColor(accentColor)
                textSize = 13.5f
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                visibility = if (showBrain && suffix.isNotEmpty()) View.VISIBLE else View.GONE
            }
            root.addView(suffixView)
            floatingPillSuffixText = suffixView

            val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }

            val defaultY = (48 * resources.displayMetrics.density).toInt().coerceAtLeast(100)
            val posX = if (hasUserMovedPill) lastPillX else 0
            val posY = if (hasUserMovedPill) lastPillY else defaultY

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                layoutFlag,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                x = posX
                y = posY
            }
            pillLayoutParams = params

            // Touch-Drag Listener + Tap-to-Open DefogMind
            root.setOnTouchListener(object : View.OnTouchListener {
                private var touchInitialX = 0
                private var touchInitialY = 0
                private var initialTouchX = 0f
                private var initialTouchY = 0f
                private var startClickTime = 0L

                override fun onTouch(v: View?, event: MotionEvent?): Boolean {
                    if (event == null || pillLayoutParams == null) return false
                    when (event.action) {
                        MotionEvent.ACTION_DOWN -> {
                            touchInitialX = pillLayoutParams!!.x
                            touchInitialY = pillLayoutParams!!.y
                            initialTouchX = event.rawX
                            initialTouchY = event.rawY
                            startClickTime = System.currentTimeMillis()
                            return true
                        }
                        MotionEvent.ACTION_MOVE -> {
                            val newX = touchInitialX + (event.rawX - initialTouchX).toInt()
                            val newY = touchInitialY + (event.rawY - initialTouchY).toInt()
                            pillLayoutParams!!.x = newX
                            pillLayoutParams!!.y = newY
                            try {
                                windowManager.updateViewLayout(floatingPillView, pillLayoutParams)
                            } catch (e: Exception) {
                                // ignore
                            }
                            return true
                        }
                        MotionEvent.ACTION_UP -> {
                            val clickDuration = System.currentTimeMillis() - startClickTime
                            val movedDistance = Math.hypot(
                                (event.rawX - initialTouchX).toDouble(),
                                (event.rawY - initialTouchY).toDouble()
                            )
                            if (movedDistance >= 15) {
                                hasUserMovedPill = true
                                lastPillX = pillLayoutParams!!.x
                                lastPillY = pillLayoutParams!!.y
                            } else if (clickDuration < 300) {
                                openDefogMindApp()
                            }
                            return true
                        }
                    }
                    return false
                }
            })

            floatingPillView = root
            try {
                windowManager.addView(floatingPillView, params)
                if (animateFadeIn) {
                    root.animate().alpha(1f).setDuration(350L).start()
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        } else {
            floatingPillView?.post {
                floatingPillView?.animate()?.cancel()
                floatingPillView?.alpha = 1f

                floatingPillPrefixText?.text = prefix
                floatingPillPrefixText?.setTextColor(accentColor)
                floatingPillPrefixText?.visibility = if (prefix.isNotEmpty()) View.VISIBLE else View.GONE

                val currentTier = when {
                    currentNetBrainFogPercent <= 30 -> 0
                    currentNetBrainFogPercent <= 60 -> 1
                    currentNetBrainFogPercent <= 90 -> 2
                    else -> 3
                }
                floatingPillBrainCharacter?.visibility = if (showBrain) View.VISIBLE else View.GONE
                floatingPillBrainCharacter?.updateTier(currentTier)

                floatingPillSuffixText?.visibility = if (showBrain && suffix.isNotEmpty()) View.VISIBLE else View.GONE
                floatingPillSuffixText?.text = suffix
                floatingPillSuffixText?.setTextColor(accentColor)

                // Update background and border color
                val isDark = PassStorage.isDarkTheme(this@FocusMonitorService)
                val pillBgColor = if (isDark) Color.parseColor("#D90B0F17") else Color.parseColor("#E6FFFFFF")
                val density = resources.displayMetrics.density
                val shape = GradientDrawable().apply {
                    setColor(pillBgColor)
                    setStroke(2, accentColor)
                    cornerRadius = 40f * density
                }
                floatingPillView?.background = shape
                floatingPillView?.visibility = View.VISIBLE
            }
        }
    }

    private fun fadeOutAndHideFloatingPill() {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post { fadeOutAndHideFloatingPill() }
            return
        }
        val view = floatingPillView ?: return
        if (isFadingOutPill) return
        isFadingOutPill = true
        view.post {
            view.animate()
                .alpha(0f)
                .setDuration(400L)
                .withEndAction {
                    isFadingOutPill = false
                    hideFloatingPill()
                }
                .start()
        }
    }

    private fun hideFloatingPill() {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post { hideFloatingPill() }
            return
        }
        isFadingOutPill = false
        floatingPillView?.post {
            if (floatingPillView != null) {
                try {
                    floatingPillView?.animate()?.cancel()
                    windowManager.removeView(floatingPillView)
                } catch (e: Exception) {
                    // ignore
                }
                floatingPillBrainCharacter?.stopAnimation()
                floatingPillView = null
                floatingPillPrefixText = null
                floatingPillBrainCharacter = null
                floatingPillSuffixText = null
            }
        }
    }

    private fun openDefogMindApp() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        if (launchIntent != null) {
            startActivity(launchIntent)
        }
    }

    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        try {
            DefogMindWidgetUpdater.updateWidgets(this)
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        super.onDestroy()
        stopMonitoring()
        scheduleServiceRestart()
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (e: Exception) {
            // ignore
        }
        try {
            unregisterReceiver(bypassReceiver)
        } catch (e: Exception) {
            // ignore
        }
        try {
            monitorThread.quitSafely()
        } catch (_: Exception) {}
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

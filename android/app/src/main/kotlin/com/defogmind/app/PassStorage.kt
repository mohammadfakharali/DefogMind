package com.defogmind.app

import android.content.Context
import android.content.SharedPreferences
import java.util.Calendar

object PassStorage {
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val PREFIX = "flutter."
    private const val KEY_FREE_PASSES = PREFIX + "free_passes_remaining"
    private const val KEY_BONUS_PASSES = PREFIX + "bonus_passes_earned"
    private const val KEY_LAST_RESET = PREFIX + "last_pass_reset_day"
    private const val KEY_DURATION = PREFIX + "oxygen_pass_duration_seconds"
    private const val KEY_APP_THEME_MODE = PREFIX + "app_theme_mode"

    const val MAX_FREE_DAILY_PASSES = 2L
    const val DEFAULT_DURATION_SECONDS = 300L

    fun isDarkTheme(context: Context): Boolean {
        val prefs = getPrefs(context)
        val mode = prefs.getString(KEY_APP_THEME_MODE, "system") ?: "system"
        return when (mode) {
            "dark" -> true
            "light" -> false
            else -> {
                val currentNightMode = context.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK
                currentNightMode == android.content.res.Configuration.UI_MODE_NIGHT_YES
            }
        }
    }

    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    fun getTodayKey(): String {
        val now = Calendar.getInstance()
        val y = now.get(Calendar.YEAR)
        val m = now.get(Calendar.MONTH) + 1
        val d = now.get(Calendar.DAY_OF_MONTH)
        return "$y-$m-$d"
    }

    private fun checkDailyReset(prefs: SharedPreferences) {
        val today = getTodayKey()
        val lastReset = prefs.getString(KEY_LAST_RESET, null)
        if (lastReset != today) {
            prefs.edit()
                .putString(KEY_LAST_RESET, today)
                .putLong(KEY_FREE_PASSES, MAX_FREE_DAILY_PASSES)
                .putLong(KEY_BONUS_PASSES, 0L)
                .apply()
        }
    }

    private fun getLongSafe(prefs: SharedPreferences, key: String, defaultVal: Long): Long {
        return try {
            prefs.getLong(key, defaultVal)
        } catch (e: Exception) {
            try {
                prefs.getInt(key, defaultVal.toInt()).toLong()
            } catch (e2: Exception) {
                defaultVal
            }
        }
    }

    fun getRemainingPasses(context: Context): Int {
        val prefs = getPrefs(context)
        checkDailyReset(prefs)
        val free = getLongSafe(prefs, KEY_FREE_PASSES, MAX_FREE_DAILY_PASSES)
        val bonus = getLongSafe(prefs, KEY_BONUS_PASSES, 0L)
        return (free + bonus).toInt().coerceAtLeast(0)
    }

    fun usePass(context: Context): Boolean {
        val prefs = getPrefs(context)
        checkDailyReset(prefs)
        val free = getLongSafe(prefs, KEY_FREE_PASSES, MAX_FREE_DAILY_PASSES)
        val bonus = getLongSafe(prefs, KEY_BONUS_PASSES, 0L)

        if (free > 0) {
            prefs.edit().putLong(KEY_FREE_PASSES, free - 1).apply()
            return true
        } else if (bonus > 0) {
            prefs.edit().putLong(KEY_BONUS_PASSES, bonus - 1).apply()
            return true
        }
        return false
    }

    fun getPassDurationSeconds(context: Context): Int {
        val prefs = getPrefs(context)
        return getLongSafe(prefs, KEY_DURATION, DEFAULT_DURATION_SECONDS).toInt()
    }
}


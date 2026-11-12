package com.defogmind.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.CountDownTimer
import android.text.Spannable
import android.text.SpannableString
import android.text.style.AbsoluteSizeSpan
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView

class OverlayActivity : Activity() {

    private var breathingTimer: CountDownTimer? = null
    private var isBreathingComplete = false
    private var blockedPackage: String = ""
    private var durationSeconds: Int = 300
    private var isKidsMode: Boolean = false
    private var kidsReason: String = "APP_LOCKED" // "APP_LOCKED" or "TIME_UP"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )

        blockedPackage = intent.getStringExtra("EXTRA_BLOCKED_PACKAGE") ?: "Social App"
        durationSeconds = intent.getIntExtra("EXTRA_DURATION", 300)
        isKidsMode = intent.getBooleanExtra("EXTRA_KIDS_MODE", false)
        kidsReason = intent.getStringExtra("EXTRA_KIDS_REASON") ?: "APP_LOCKED"

        val rootView = if (isKidsMode) createKidsBlockerView() else createBlockerView()
        setContentView(rootView)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        if (intent != null) {
            setIntent(intent)
            blockedPackage = intent.getStringExtra("EXTRA_BLOCKED_PACKAGE") ?: blockedPackage
            durationSeconds = intent.getIntExtra("EXTRA_DURATION", durationSeconds)
            val newKidsMode = intent.getBooleanExtra("EXTRA_KIDS_MODE", false)
            val newKidsReason = intent.getStringExtra("EXTRA_KIDS_REASON") ?: "APP_LOCKED"
            if (newKidsMode != isKidsMode || newKidsReason != kidsReason) {
                isKidsMode = newKidsMode
                kidsReason = newKidsReason
                breathingTimer?.cancel()
                val rootView = if (isKidsMode) createKidsBlockerView() else createBlockerView()
                setContentView(rootView)
            }
        }
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    private fun createKidsBlockerView(): View {
        val isTimeUp = (kidsReason == "TIME_UP")
        val accentColor = if (isTimeUp) Color.parseColor("#F59E0B") else Color.parseColor("#06B6D4")
        val isDark = PassStorage.isDarkTheme(this)
        val bgColor = if (isDark) Color.parseColor("#0B0F17") else Color.parseColor("#F8FAFC")
        val cardBgColor = if (isDark) Color.parseColor("#161E2E") else Color.WHITE
        val textPrimaryColor = if (isDark) Color.WHITE else Color.parseColor("#0F172A")
        val textSecondaryColor = if (isDark) Color.parseColor("#94A3B8") else Color.parseColor("#475569")

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(bgColor)
            setPadding(dp(24), dp(32), dp(24), dp(32))
        }

        val badge = TextView(this).apply {
            text = if (isTimeUp) "⏰ KIDS TIME FINISHED" else "🔒 LOCKED IN KIDS MODE"
            textSize = 11.5f
            setTextColor(accentColor)
            gravity = Gravity.CENTER
            val shape = GradientDrawable().apply {
                setColor(cardBgColor)
                setStroke(dp(1), accentColor)
                cornerRadius = dp(20).toFloat()
            }
            background = shape
            setPadding(dp(16), dp(6), dp(16), dp(6))
        }
        root.addView(badge)

        val spacer1 = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(1, dp(18))
        }
        root.addView(spacer1)

        val titleView = TextView(this).apply {
            text = if (isTimeUp) "Screen Time Is Up!" else "App Locked by Parent"
            textSize = 24f
            setTextColor(textPrimaryColor)
            gravity = Gravity.CENTER
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        }
        root.addView(titleView)

        val subtitleView = TextView(this).apply {
            text = if (isTimeUp) {
                "Your allowed Kids Mode screen time has finished. Please return the phone to your parent."
            } else {
                "This app is blocked while Kids Mode is active. Only parent-approved apps can be opened."
            }
            textSize = 13.5f
            setTextColor(textSecondaryColor)
            gravity = Gravity.CENTER
            setPadding(dp(12), dp(10), dp(12), dp(24))
        }
        root.addView(subtitleView)

        // Primary Button: Go To Home Screen
        val exitButton = Button(this).apply {
            isAllCaps = false
            minHeight = 0
            minimumHeight = 0
            gravity = Gravity.CENTER
            setPadding(dp(16), dp(10), dp(16), dp(10))
            val fullText = "Go To Home Screen\n(Leave This App)"
            val spannable = SpannableString(fullText).apply {
                setSpan(AbsoluteSizeSpan(14, true), 0, 17, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
                setSpan(AbsoluteSizeSpan(11, true), 18, fullText.length, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
            text = spannable
            setTextColor(Color.BLACK)
            val shape = GradientDrawable().apply {
                setColor(Color.parseColor("#10B981"))
                cornerRadius = dp(16).toFloat()
            }
            background = shape
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, dp(6), 0, dp(12))
            }
            setOnClickListener {
                goToHomeScreen()
            }
        }
        root.addView(exitButton)

        // Secondary Button: Parent Unlock (Open DefogMind)
        val parentUnlockButton = Button(this).apply {
            isAllCaps = false
            minHeight = 0
            minimumHeight = 0
            gravity = Gravity.CENTER
            setPadding(dp(16), dp(10), dp(16), dp(10))
            val fullText = "🔐 Parent Unlock\n(Open DefogMind & Enter PIN)"
            val spannable = SpannableString(fullText).apply {
                setSpan(AbsoluteSizeSpan(14, true), 0, 16, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
                setSpan(AbsoluteSizeSpan(11, true), 17, fullText.length, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
            text = spannable
            setTextColor(Color.WHITE)
            val shape = GradientDrawable().apply {
                setColor(Color.parseColor("#161E2E"))
                setStroke(dp(1), Color.parseColor("#243046"))
                cornerRadius = dp(16).toFloat()
            }
            background = shape
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            setOnClickListener {
                openDefogMindDashboard()
            }
        }
        root.addView(parentUnlockButton)

        return root
    }

    private fun createBlockerView(): View {
        val isDark = PassStorage.isDarkTheme(this)
        val bgColor = if (isDark) Color.parseColor("#0B0F17") else Color.parseColor("#F8FAFC")
        val cardBgColor = if (isDark) Color.parseColor("#161E2E") else Color.WHITE
        val cardBorderColor = if (isDark) Color.parseColor("#243046") else Color.parseColor("#E2E8F0")
        val textPrimaryColor = if (isDark) Color.WHITE else Color.parseColor("#0F172A")
        val textSecondaryColor = if (isDark) Color.parseColor("#94A3B8") else Color.parseColor("#475569")
        val textMutedColor = if (isDark) Color.parseColor("#64748B") else Color.parseColor("#94A3B8")

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(bgColor)
            setPadding(dp(24), dp(32), dp(24), dp(32))
        }

        // Tag badge
        val badge = TextView(this).apply {
            text = "DAILY LIMIT REACHED"
            textSize = 11.5f
            setTextColor(Color.parseColor("#EF4444"))
            gravity = Gravity.CENTER
            val shape = GradientDrawable().apply {
                setColor(if (isDark) Color.parseColor("#26161E2E") else Color.parseColor("#1AEF4444"))
                setStroke(dp(1), Color.parseColor("#EF4444"))
                cornerRadius = dp(20).toFloat()
            }
            background = shape
            setPadding(dp(16), dp(6), dp(16), dp(6))
        }
        root.addView(badge)

        val spacer1 = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(1, dp(18))
        }
        root.addView(spacer1)

        // Title
        val titleView = TextView(this).apply {
            text = "Focus Shield Active"
            textSize = 24f
            setTextColor(textPrimaryColor)
            gravity = Gravity.CENTER
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        }
        root.addView(titleView)

        // Subtitle (5th grade level plain English)
        val subtitleView = TextView(this).apply {
            text = "You have reached your daily screen time limit. Take a short pause and breathe."
            textSize = 13.5f
            setTextColor(textSecondaryColor)
            gravity = Gravity.CENTER
            setPadding(dp(12), dp(10), dp(12), dp(20))
        }
        root.addView(subtitleView)

        // Breathing Card
        val breathingCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            val shape = GradientDrawable().apply {
                setColor(cardBgColor)
                setStroke(dp(1), cardBorderColor)
                cornerRadius = dp(18).toFloat()
            }
            background = shape
            setPadding(dp(20), dp(18), dp(20), dp(18))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, dp(8), 0, dp(22))
            }
        }

        val breathingText = TextView(this).apply {
            text = "Breathe in slowly... (10s)"
            textSize = 14.5f
            setTextColor(Color.parseColor("#10B981"))
            gravity = Gravity.CENTER
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        }
        breathingCard.addView(breathingText)

        val progressBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            progress = 0
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(8)
            ).apply {
                setMargins(0, dp(12), 0, 0)
            }
        }
        breathingCard.addView(progressBar)
        root.addView(breathingCard)

        val durationMinutes = durationSeconds / 60

        // Top Action Button: Emergency Bypass
        val bypassButton = Button(this).apply {
            isAllCaps = false
            minHeight = 0
            minimumHeight = 0
            gravity = Gravity.CENTER
            setPadding(dp(16), dp(10), dp(16), dp(10))
            text = "Take a breath to unlock (10s)"
            isEnabled = false
            textSize = 13.5f
            setTextColor(Color.parseColor("#64748B"))
            val shape = GradientDrawable().apply {
                setColor(Color.parseColor("#1E293B"))
                cornerRadius = dp(16).toFloat()
            }
            background = shape
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, dp(4), 0, dp(12))
            }
        }
        root.addView(bypassButton)

        // Bottom Action Button: Leave The App (Go To Home)
        val exitButton = Button(this).apply {
            isAllCaps = false
            minHeight = 0
            minimumHeight = 0
            gravity = Gravity.CENTER
            setPadding(dp(16), dp(10), dp(16), dp(10))
            val fullText = "Leave The App\n(Go To Home)"
            val spannable = SpannableString(fullText).apply {
                setSpan(AbsoluteSizeSpan(14, true), 0, 13, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
                setSpan(AbsoluteSizeSpan(11, true), 14, fullText.length, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
            text = spannable
            setTextColor(Color.WHITE)
            val shape = GradientDrawable().apply {
                setColor(Color.parseColor("#06B6D4"))
                cornerRadius = dp(16).toFloat()
            }
            background = shape
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            setOnClickListener {
                goToHomeScreen()
            }
        }
        root.addView(exitButton)

        // Disclaimer at bottom
        val disclaimer = TextView(this).apply {
            text = "DefogMind is a digital habit and productivity utility. It does not provide medical advice, diagnosis, or treatment for cognitive conditions."
            textSize = 10.5f
            setTextColor(textMutedColor)
            gravity = Gravity.CENTER
            setPadding(dp(12), dp(22), dp(12), 0)
        }
        root.addView(disclaimer)

        // 10-second breathing timer
        breathingTimer = object : CountDownTimer(10000, 100) {
            override fun onTick(millisUntilFinished: Long) {
                val secondsRemaining = (millisUntilFinished / 1000) + 1
                val progress = ((10000 - millisUntilFinished) * 100 / 10000).toInt()
                progressBar.progress = progress

                val cycle = (10000 - millisUntilFinished) / 1000
                val phase = if (cycle < 4) "Breathe in..." else if (cycle < 7) "Hold gently..." else "Exhale slowly..."
                breathingText.text = "$phase (${secondsRemaining}s)"
                bypassButton.text = "Sit with the breath (${secondsRemaining}s)"
            }

            override fun onFinish() {
                isBreathingComplete = true
                progressBar.progress = 100
                breathingText.text = "Breathing finished! You can now unlock."
                breathingText.setTextColor(Color.parseColor("#06B6D4"))

                val remainingPasses = PassStorage.getRemainingPasses(this@OverlayActivity)
                bypassButton.isEnabled = true

                if (remainingPasses > 0) {
                    val line1 = "Claim $durationMinutes Minutes"
                    val line2 = "(Extra unlock • $remainingPasses left)"
                    val buttonText = "$line1\n$line2"
                    val spannable = SpannableString(buttonText).apply {
                        setSpan(AbsoluteSizeSpan(14, true), 0, line1.length, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
                        setSpan(AbsoluteSizeSpan(11, true), line1.length + 1, buttonText.length, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
                    }
                    bypassButton.text = spannable
                    bypassButton.setTextColor(Color.BLACK)
                    val activeShape = GradientDrawable().apply {
                        setColor(Color.parseColor("#10B981"))
                        cornerRadius = dp(16).toFloat()
                    }
                    bypassButton.background = activeShape
                    bypassButton.setOnClickListener {
                        grantBypassAndDismiss()
                    }
                } else {
                    val line1 = "No Passes Left"
                    val line2 = "(Tap to open DefogMind & earn pass)"
                    val buttonText = "$line1\n$line2"
                    val spannable = SpannableString(buttonText).apply {
                        setSpan(AbsoluteSizeSpan(14, true), 0, line1.length, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
                        setSpan(AbsoluteSizeSpan(11, true), line1.length + 1, buttonText.length, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
                    }
                    bypassButton.text = spannable
                    bypassButton.setTextColor(Color.WHITE)
                    val amberShape = GradientDrawable().apply {
                        setColor(Color.parseColor("#F59E0B"))
                        cornerRadius = dp(16).toFloat()
                    }
                    bypassButton.background = amberShape
                    bypassButton.setOnClickListener {
                        openDefogMindDashboard()
                    }
                }
            }
        }.start()

        return root
    }

    private fun grantBypassAndDismiss() {
        val success = PassStorage.usePass(this)
        if (success) {
            val intent = Intent(FocusMonitorService.ACTION_CLAIM_OXYGEN_PASS).apply {
                putExtra("EXTRA_DURATION", durationSeconds)
            }
            sendBroadcast(intent)
            finish()
        } else {
            openDefogMindDashboard()
        }
    }

    private fun openDefogMindDashboard() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        if (launchIntent != null) {
            startActivity(launchIntent)
        }
        finish()
    }

    private fun goToHomeScreen() {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        finish()
    }

    override fun onBackPressed() {
        goToHomeScreen()
    }

    override fun onDestroy() {
        super.onDestroy()
        breathingTimer?.cancel()
    }
}

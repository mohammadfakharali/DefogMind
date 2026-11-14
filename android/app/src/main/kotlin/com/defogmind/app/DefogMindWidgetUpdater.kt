package com.defogmind.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.widget.RemoteViews
import kotlin.math.*

object DefogMindWidgetUpdater {

    fun updateWidgets(context: Context) {
        try {
            val appWidgetManager = AppWidgetManager.getInstance(context) ?: return
            val componentName = ComponentName(context, DefogMindWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            if (appWidgetIds == null || appWidgetIds.isEmpty()) return

            val prefs = context.getSharedPreferences(FocusMonitorService.PREFS_NAME, Context.MODE_PRIVATE)
            val fog = if (FocusMonitorService.isServiceRunning) {
                FocusMonitorService.liveNetBrainFogPercent
            } else {
                prefs.getFloat(FocusMonitorService.KEY_CENTRAL_AWARENESS_FOG, 0f).roundToInt()
            }.coerceIn(0, 100)

            val totalMins = if (FocusMonitorService.isServiceRunning) {
                FocusMonitorService.liveTodaySocialMinutes
            } else {
                prefs.getInt("cached_today_social_minutes", 0)
            }
            val focusMode = prefs.getInt(FocusMonitorService.KEY_FOCUS_MODE, 1)
            val limitMins = prefs.getInt("daily_limit_minutes", 60)

            val tier = when {
                fog <= 30 -> 0
                fog <= 60 -> 1
                fog <= 90 -> 2
                else -> 3
            }

            // Respect App Theme Mode: System, Dark, or Light
            val isDark = PassStorage.isDarkTheme(context)
            val bgDrawable = if (isDark) R.drawable.widget_bg_card else R.drawable.widget_bg_card_light
            val pillDrawable = if (isDark) R.drawable.widget_pill_bg else R.drawable.widget_pill_bg_light
            val brandColorHex = if (isDark) "#94A3B8" else "#64748B"
            val subColorHex = if (isDark) "#94A3B8" else "#64748B"

            val (title, colorHex) = when (tier) {
                0 -> Pair("Fresh Mind 😊", if (isDark) "#10B981" else "#059669")
                1 -> Pair("Tired Mind 😐", if (isDark) "#F59E0B" else "#D97706")
                2 -> Pair("Heavy Mind 😵‍💫", if (isDark) "#FB923C" else "#EA580C")
                else -> Pair("Overloaded Mind 🤯", if (isDark) "#EF4444" else "#E11D48")
            }

            val subText = if (focusMode == 1 && limitMins > 0) {
                "${totalMins}m / ${limitMins}m used"
            } else {
                "${totalMins}m used today"
            }

            // Tap action: opens DefogMind App
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java)
            launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Render live mascot bitmap
            val mascotBitmap = renderMascotBitmap(tier, isDark)

            for (appWidgetId in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.widget_compact).apply {
                    setInt(R.id.widget_compact_root, "setBackgroundResource", bgDrawable)
                    setInt(R.id.widget_compact_badge, "setBackgroundResource", pillDrawable)
                    setTextViewText(R.id.widget_compact_app_name, "DEFOGMIND")
                    setTextColor(R.id.widget_compact_app_name, Color.parseColor(brandColorHex))
                    setTextViewText(R.id.widget_compact_badge, "$fog% Fog")
                    setTextColor(R.id.widget_compact_badge, Color.parseColor(colorHex))
                    setTextViewText(R.id.widget_compact_title, title)
                    setTextColor(R.id.widget_compact_title, Color.parseColor(colorHex))
                    setTextViewText(R.id.widget_compact_sub, subText)
                    setTextColor(R.id.widget_compact_sub, Color.parseColor(subColorHex))
                    if (mascotBitmap != null) {
                        setImageViewBitmap(R.id.widget_compact_character, mascotBitmap)
                    }
                    setOnClickPendingIntent(R.id.widget_compact_root, pendingIntent)
                }
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        } catch (_: Exception) {
            // Widget update safeguard
        }
    }

    private fun renderMascotBitmap(tier: Int, isDark: Boolean): Bitmap? {
        try {
            val size = 260
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)

            val w = size.toFloat()
            val h = size.toFloat()
            val zoom = 1.05f * 1.06f // Scaled up to fill the widget space cleanly
            val offsetX = 0.020f
            val offsetY = 0.035f

            val cx = w * (0.50f + offsetX)
            val cy = h * (0.42f + offsetY)
            val rx = (w * 0.35f) * zoom
            val ry = (w * 0.26f) * zoom
            val groundY = cy + ry * 1.55f
            val legTopY = cy + ry * 0.78f

            val auraColor = when (tier) {
                0 -> if (isDark) "#10B981" else "#059669"
                1 -> if (isDark) "#F59E0B" else "#D97706"
                2 -> if (isDark) "#F97316" else "#EA580C"
                else -> if (isDark) "#F43F5E" else "#E11D48"
            }

            // 1. Ambient Aura
            val auraPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = RadialGradient(
                    cx, cy, rx * 1.35f,
                    intArrayOf(Color.parseColor(auraColor), Color.parseColor(auraColor), Color.TRANSPARENT),
                    floatArrayOf(0f, 0.45f, 1f),
                    Shader.TileMode.CLAMP
                )
                alpha = if (isDark) 60 else 38
            }
            canvas.drawCircle(cx, cy, rx * 1.35f, auraPaint)

            // 2. Legs
            val legPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#E8637A")
                style = Paint.Style.STROKE
                strokeWidth = max(3.0f, rx * 0.11f)
                strokeCap = Paint.Cap.ROUND
            }

            val path = Path()
            path.moveTo(cx - rx * 0.36f, legTopY)
            path.quadTo(cx - rx * 0.40f, (legTopY + groundY) / 2f, cx - rx * 0.42f, groundY - 4f)
            canvas.drawPath(path, legPaint)

            path.reset()
            path.moveTo(cx + rx * 0.36f, legTopY)
            path.quadTo(cx + rx * 0.40f, (legTopY + groundY) / 2f, cx + rx * 0.42f, groundY - 4f)
            canvas.drawPath(path, legPaint)

            // Ground shadows
            val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.argb(35, 0, 0, 0)
                style = Paint.Style.FILL
            }
            canvas.drawOval(RectF(cx - rx * 0.56f, groundY + 1f, cx - rx * 0.28f, groundY + 6f), shadowPaint)
            canvas.drawOval(RectF(cx + rx * 0.28f, groundY + 1f, cx + rx * 0.56f, groundY + 6f), shadowPaint)

            // Sneakers
            drawSneaker(canvas, cx - rx * 0.42f, groundY, isLeft = true, scale = zoom * (w / 112f))
            drawSneaker(canvas, cx + rx * 0.42f, groundY, isLeft = false, scale = zoom * (w / 112f))

            // 3. Cloud Brain Body
            val cloudPath = Path()
            cloudPath.moveTo(cx, cy - ry * 0.90f)
            cloudPath.cubicTo(cx + rx * 0.15f, cy - ry * 1.08f, cx + rx * 0.38f, cy - ry * 1.08f, cx + rx * 0.50f, cy - ry * 0.88f)
            cloudPath.cubicTo(cx + rx * 0.65f, cy - ry * 0.95f, cx + rx * 0.85f, cy - ry * 0.80f, cx + rx * 0.92f, cy - ry * 0.55f)
            cloudPath.cubicTo(cx + rx * 1.08f, cy - ry * 0.40f, cx + rx * 1.12f, cy - ry * 0.10f, cx + rx * 1.02f, cy + ry * 0.15f)
            cloudPath.cubicTo(cx + rx * 1.12f, cy + ry * 0.30f, cx + rx * 1.05f, cy + ry * 0.55f, cx + rx * 0.88f, cy + ry * 0.68f)
            cloudPath.cubicTo(cx + rx * 0.85f, cy + ry * 0.88f, cx + rx * 0.60f, cy + ry * 0.98f, cx + rx * 0.38f, cy + ry * 0.88f)
            cloudPath.cubicTo(cx + rx * 0.25f, cy + ry * 0.95f, cx + rx * 0.10f, cy + ry * 0.92f, cx, cy + ry * 0.85f)

            cloudPath.cubicTo(cx - rx * 0.10f, cy + ry * 0.92f, cx - rx * 0.25f, cy + ry * 0.95f, cx - rx * 0.38f, cy + ry * 0.88f)
            cloudPath.cubicTo(cx - rx * 0.60f, cy + ry * 0.98f, cx - rx * 0.85f, cy + ry * 0.88f, cx - rx * 0.88f, cy + ry * 0.68f)
            cloudPath.cubicTo(cx - rx * 1.05f, cy + ry * 0.55f, cx - rx * 1.12f, cy + ry * 0.30f, cx - rx * 1.02f, cy + ry * 0.15f)
            cloudPath.cubicTo(cx - rx * 1.12f, cy - ry * 0.10f, cx - rx * 1.08f, cy - ry * 0.40f, cx - rx * 0.92f, cy - ry * 0.55f)
            cloudPath.cubicTo(cx - rx * 0.85f, cy - ry * 0.80f, cx - rx * 0.65f, cy - ry * 0.95f, cx - rx * 0.50f, cy - ry * 0.88f)
            cloudPath.cubicTo(cx - rx * 0.38f, cy - ry * 1.08f, cx - rx * 0.15f, cy - ry * 1.08f, cx, cy - ry * 0.90f)
            cloudPath.close()

            val (c1, c2, c3, outColor, foldColor) = when (tier) {
                0 -> listOf("#FFDFE6", "#FFB4C4", "#F28DA2", "#B53952", "#D95874")
                1 -> listOf("#FFD8E0", "#F8A8B9", "#E28096", "#A8324A", "#A8324A")
                2 -> listOf("#F8CED7", "#E89BA9", "#D27286", "#982A40", "#982A40")
                else -> listOf("#F2C8D2", "#DE9FA9", "#C07684", "#882337", "#882337")
            }

            val bodyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(
                    cx, cy - ry, cx, cy + ry,
                    intArrayOf(Color.parseColor(c1), Color.parseColor(c2), Color.parseColor(c3)),
                    floatArrayOf(0f, 0.55f, 1f),
                    Shader.TileMode.CLAMP
                )
            }
            canvas.drawPath(cloudPath, bodyPaint)

            val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor(outColor)
                style = Paint.Style.STROKE
                strokeWidth = max(2.0f, rx * 0.055f)
                strokeCap = Paint.Cap.ROUND
                strokeJoin = Paint.Join.ROUND
            }
            canvas.drawPath(cloudPath, strokePaint)

            // 4. Arms & Cartoon Gloves
            val armPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#E8637A")
                style = Paint.Style.STROKE
                strokeWidth = max(3.0f, rx * 0.11f)
                strokeCap = Paint.Cap.ROUND
            }

            if (tier == 0) {
                // Joyful Waving Left Arm
                path.reset()
                path.moveTo(cx - rx * 0.88f, cy + ry * 0.20f)
                path.quadTo(cx - rx * 1.15f, cy, cx - rx * 1.25f, cy - ry * 0.30f)
                canvas.drawPath(path, armPaint)
                drawGlove(canvas, cx - rx * 1.25f, cy - ry * 0.30f, rx * 0.16f)
            } else {
                path.reset()
                path.moveTo(cx - rx * 0.88f, cy + ry * 0.20f)
                path.quadTo(cx - rx * 1.15f, cy + ry * 0.35f, cx - rx * 1.05f, cy + ry * 0.50f)
                canvas.drawPath(path, armPaint)
                drawGlove(canvas, cx - rx * 1.05f, cy + ry * 0.50f, rx * 0.16f)
            }

            // Right Arm
            path.reset()
            path.moveTo(cx + rx * 0.88f, cy + ry * 0.20f)
            path.quadTo(cx + rx * 1.20f, cy + ry * 0.35f, cx + rx * 1.05f, cy + ry * 0.50f)
            canvas.drawPath(path, armPaint)
            drawGlove(canvas, cx + rx * 1.05f, cy + ry * 0.50f, rx * 0.16f)

            // 5. Internal Folds
            val foldPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor(foldColor)
                style = Paint.Style.STROKE
                strokeWidth = max(1.5f, rx * 0.038f)
                strokeCap = Paint.Cap.ROUND
            }

            fun drawFold(x1: Float, y1: Float, cpx: Float, cpy: Float, x2: Float, y2: Float) {
                val p = Path()
                p.moveTo(cx + rx * x1, cy + ry * y1)
                p.quadTo(cx + rx * cpx, cy + ry * cpy, cx + rx * x2, cy + ry * y2)
                canvas.drawPath(p, foldPaint)
            }

            drawFold(0.0f, -0.90f, -0.02f, -0.70f, 0.0f, -0.52f)
            drawFold(-0.25f, -0.85f, -0.40f, -0.68f, -0.20f, -0.52f)
            drawFold(-0.55f, -0.80f, -0.70f, -0.60f, -0.50f, -0.45f)
            drawFold(0.25f, -0.85f, 0.40f, -0.68f, 0.20f, -0.52f)
            drawFold(0.55f, -0.80f, 0.70f, -0.60f, 0.50f, -0.45f)

            // 6. Face Expressions per Tier
            val eyeSpacing = rx * 0.35f
            val eyeY = cy + ry * 0.08f
            val eyeW = rx * 0.25f
            val eyeH = ry * 0.44f

            when (tier) {
                0 -> {
                    // Fresh Mind - big eyes, catchlights, smile, clarity star
                    drawEyes(canvas, cx, eyeSpacing, eyeY, eyeW, eyeH, rx, withCatchlights = true)
                    drawSmile(canvas, cx, eyeY, rx, ry)
                    drawStar(canvas, cx + rx * 0.88f, cy - ry * 0.80f, max(3.2f, rx * 0.09f), Color.parseColor("#10B981"))
                }
                1 -> {
                    // Mild Haze - slightly drooping eyes, neutral mouth
                    drawEyes(canvas, cx, eyeSpacing, eyeY, eyeW, eyeH * 0.78f, rx, withCatchlights = false)
                    drawNeutralMouth(canvas, cx, eyeY + ry * 0.38f, rx * 0.16f)
                }
                2 -> {
                    // Brain Fog - dizzy swirl eyes, wavy mouth
                    drawSwirlEye(canvas, cx - eyeSpacing, eyeY, eyeW * 0.38f)
                    drawSwirlEye(canvas, cx + eyeSpacing, eyeY, eyeW * 0.38f)
                    drawWavyMouth(canvas, cx, eyeY + ry * 0.38f, rx * 0.18f)
                }
                else -> {
                    // Overloaded - dizzy crossed eyes (X X), shivering mouth
                    drawXEye(canvas, cx - eyeSpacing, eyeY, eyeW * 0.35f)
                    drawXEye(canvas, cx + eyeSpacing, eyeY, eyeW * 0.35f)
                    drawWavyMouth(canvas, cx, eyeY + ry * 0.40f, rx * 0.20f)
                }
            }

            return bitmap
        } catch (_: Exception) {
            return null
        }
    }

    private fun drawEyes(canvas: Canvas, cx: Float, eyeSpacing: Float, eyeY: Float, eyeW: Float, eyeH: Float, rx: Float, withCatchlights: Boolean) {
        val leftEye = RectF(cx - eyeSpacing - eyeW / 2f, eyeY - eyeH / 2f, cx - eyeSpacing + eyeW / 2f, eyeY + eyeH / 2f)
        val rightEye = RectF(cx + eyeSpacing - eyeW / 2f, eyeY - eyeH / 2f, cx + eyeSpacing + eyeW / 2f, eyeY + eyeH / 2f)

        val scleraPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
        val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#0F172A")
            style = Paint.Style.STROKE
            strokeWidth = max(1.8f, rx * 0.045f)
        }

        canvas.drawOval(leftEye, scleraPaint)
        canvas.drawOval(leftEye, strokePaint)
        canvas.drawOval(rightEye, scleraPaint)
        canvas.drawOval(rightEye, strokePaint)

        val pupilR = eyeW * 0.35f
        val pupilPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#1E293B") }
        canvas.drawCircle(cx - eyeSpacing + eyeW * 0.08f, eyeY - eyeH * 0.04f, pupilR, pupilPaint)
        canvas.drawCircle(cx + eyeSpacing + eyeW * 0.08f, eyeY - eyeH * 0.04f, pupilR, pupilPaint)

        if (withCatchlights) {
            val sparkPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
            canvas.drawCircle(cx - eyeSpacing, eyeY - pupilR * 0.5f, pupilR * 0.42f, sparkPaint)
            canvas.drawCircle(cx + eyeSpacing, eyeY - pupilR * 0.5f, pupilR * 0.42f, sparkPaint)
        }

        // Brows
        val browPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#4A101D")
            style = Paint.Style.STROKE
            strokeWidth = max(2.0f, rx * 0.05f)
            strokeCap = Paint.Cap.ROUND
        }
        val leftBrow = Path().apply {
            moveTo(cx - eyeSpacing - eyeW * 0.45f, eyeY - eyeH * 0.65f)
            quadTo(cx - eyeSpacing, eyeY - eyeH * 0.90f, cx - eyeSpacing + eyeW * 0.45f, eyeY - eyeH * 0.60f)
        }
        canvas.drawPath(leftBrow, browPaint)

        val rightBrow = Path().apply {
            moveTo(cx + eyeSpacing - eyeW * 0.45f, eyeY - eyeH * 0.60f)
            quadTo(cx + eyeSpacing, eyeY - eyeH * 0.90f, cx + eyeSpacing + eyeW * 0.45f, eyeY - eyeH * 0.65f)
        }
        canvas.drawPath(rightBrow, browPaint)
    }

    private fun drawSmile(canvas: Canvas, cx: Float, eyeY: Float, rx: Float, ry: Float) {
        val mouthY = eyeY + ry * 0.34f
        val mouthW = rx * 0.22f
        val mouthH = ry * 0.34f

        val mouthPath = Path().apply {
            moveTo(cx - mouthW, mouthY)
            quadTo(cx, mouthY + mouthH, cx + mouthW, mouthY)
            close()
        }

        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#2C0B12") }
        canvas.drawPath(mouthPath, fillPaint)

        canvas.save()
        canvas.clipPath(mouthPath)
        val tonguePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#FF6584") }
        canvas.drawCircle(cx, mouthY + mouthH * 0.70f, mouthW * 0.65f, tonguePaint)
        canvas.restore()

        val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#0F172A")
            style = Paint.Style.STROKE
            strokeWidth = max(1.6f, rx * 0.042f)
            strokeCap = Paint.Cap.ROUND
        }
        canvas.drawPath(mouthPath, strokePaint)
    }

    private fun drawNeutralMouth(canvas: Canvas, cx: Float, y: Float, w: Float) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#2C0B12")
            style = Paint.Style.STROKE
            strokeWidth = 2.4f
            strokeCap = Paint.Cap.ROUND
        }
        canvas.drawLine(cx - w, y, cx + w, y, paint)
    }

    private fun drawWavyMouth(canvas: Canvas, cx: Float, y: Float, w: Float) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#2C0B12")
            style = Paint.Style.STROKE
            strokeWidth = 2.4f
            strokeCap = Paint.Cap.ROUND
        }
        val p = Path().apply {
            moveTo(cx - w, y)
            quadTo(cx - w * 0.5f, y - 3f, cx, y)
            quadTo(cx + w * 0.5f, y + 3f, cx + w, y)
        }
        canvas.drawPath(p, paint)
    }

    private fun drawSwirlEye(canvas: Canvas, x: Float, y: Float, r: Float) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#1E293B")
            style = Paint.Style.STROKE
            strokeWidth = 2.4f
            strokeCap = Paint.Cap.ROUND
        }
        val p = Path()
        var a = 0f
        while (a < Math.PI.toFloat() * 4f) {
            val rad = (r * a) / (Math.PI.toFloat() * 4f)
            val px = x + cos(a) * rad
            val py = y + sin(a) * rad
            if (a == 0f) p.moveTo(px, py) else p.lineTo(px, py)
            a += 0.25f
        }
        canvas.drawPath(p, paint)
    }

    private fun drawXEye(canvas: Canvas, x: Float, y: Float, r: Float) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#882337")
            style = Paint.Style.STROKE
            strokeWidth = 3.0f
            strokeCap = Paint.Cap.ROUND
        }
        canvas.drawLine(x - r, y - r, x + r, y + r, paint)
        canvas.drawLine(x + r, y - r, x - r, y + r, paint)
    }

    private fun drawGlove(canvas: Canvas, x: Float, y: Float, r: Float) {
        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
        val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#0F172A")
            style = Paint.Style.STROKE
            strokeWidth = 1.4f
        }
        canvas.drawCircle(x, y, r, fillPaint)
        canvas.drawCircle(x, y, r, strokePaint)

        // Thumb
        canvas.drawCircle(x + r * 0.45f, y - r * 0.25f, r * 0.52f, fillPaint)
        canvas.drawCircle(x + r * 0.45f, y - r * 0.25f, r * 0.52f, strokePaint)
    }

    private fun drawSneaker(canvas: Canvas, x: Float, y: Float, isLeft: Boolean, scale: Float) {
        val dir = if (isLeft) -1f else 1f
        val shoeLength = 14f * scale
        val shoeHeight = 7f * scale
        val heelX = x - dir * (2f * scale)
        val toeX = x + dir * shoeLength
        val ankleY = y - shoeHeight

        val shoeBody = Path().apply {
            moveTo(heelX, y)
            lineTo(heelX, ankleY)
            lineTo(x + dir * (3f * scale), ankleY + (1.5f * scale))
            lineTo(toeX - dir * (4f * scale), y - (3f * scale))
            lineTo(toeX, y)
            close()
        }

        val canvasPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#1E293B") }
        canvas.drawPath(shoeBody, canvasPaint)

        val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#0F172A")
            style = Paint.Style.STROKE
            strokeWidth = max(1.2f, scale * 0.9f)
        }
        canvas.drawPath(shoeBody, strokePaint)

        // White rubber sole
        val soleHeight = 2.5f * scale
        val soleRect = RectF(min(heelX, toeX), y - soleHeight, max(heelX, toeX), y)
        val whitePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
        canvas.drawRect(soleRect, whitePaint)
        canvas.drawRect(soleRect, strokePaint)

        // White toe cap
        canvas.drawCircle(toeX - dir * (1.5f * scale), y - (1.5f * scale), 2.6f * scale, whitePaint)
        canvas.drawCircle(toeX - dir * (1.5f * scale), y - (1.5f * scale), 2.6f * scale, strokePaint)
    }

    private fun drawStar(canvas: Canvas, x: Float, y: Float, r: Float, color: Int) {
        val path = Path()
        for (i in 0 until 4) {
            val a = (i * Math.PI.toFloat()) / 2f
            val px = x + cos(a) * r
            val py = y + sin(a) * r
            if (i == 0) path.moveTo(px, py) else path.lineTo(px, py)
            val midA = a + Math.PI.toFloat() / 4f
            path.lineTo(x + cos(midA) * (r * 0.35f), y + sin(midA) * (r * 0.35f))
        }
        path.close()
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }
        canvas.drawPath(path, p)
    }
}

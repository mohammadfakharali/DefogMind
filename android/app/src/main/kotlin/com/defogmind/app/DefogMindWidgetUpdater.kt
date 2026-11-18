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
                fog <= 50 -> 1
                fog <= 80 -> 2
                else -> 3
            }

            // Respect App Theme Mode: System, Dark, or Light
            val isDark = PassStorage.isDarkTheme(context)
            val bgDrawable = if (isDark) R.drawable.widget_bg_card else R.drawable.widget_bg_card_light
            val pillDrawable = if (isDark) R.drawable.widget_pill_bg else R.drawable.widget_pill_bg_light
            val brandColorHex = if (isDark) "#94A3B8" else "#64748B"

            val (title, colorHex) = when (tier) {
                0 -> Pair("Fresh Mind", if (isDark) "#10B981" else "#059669")
                1 -> Pair("Tired Mind", if (isDark) "#F59E0B" else "#D97706")
                2 -> Pair("Heavy Mind", if (isDark) "#FB923C" else "#EA580C")
                else -> Pair("Overloaded Mind", if (isDark) "#EF4444" else "#E11D48")
            }

            // Prominent Minutes Used: Bold and shifts color (Amber -> Red) as limit runs out
            val (subText, subColorHex) = if (focusMode == 1 && limitMins > 0) {
                val remainingMins = (limitMins - totalMins).coerceAtLeast(0)
                val limitRatio = totalMins.toFloat() / limitMins.toFloat()
                val text = "${totalMins}m / ${limitMins}m used"
                val color = when {
                    remainingMins <= 5 || limitRatio >= 0.90f -> if (isDark) "#EF4444" else "#DC2626"
                    remainingMins <= 15 || limitRatio >= 0.75f -> if (isDark) "#F59E0B" else "#D97706"
                    else -> if (isDark) "#FFFFFF" else "#0F172A"
                }
                Pair(text, color)
            } else {
                val text = "${totalMins}m used today"
                val color = if (isDark) "#E2E8F0" else "#1E293B"
                Pair(text, color)
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
            val zoom = 0.98f
            // Shifted right to avoid cutting the waving left hand on the widget card edge
            val offsetX = 0.058f
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

            // 2. Legs & Sneakers
            val (legCol, legOut) = when (tier) {
                0 -> Pair("#D95874", "#B53952")
                1 -> Pair("#CA5A70", "#A8324A")
                2 -> Pair("#B8485E", "#982A40")
                else -> Pair("#A0384E", "#882337")
            }

            val legW = max(3.0f, rx * 0.24f)
            val leftHipX = cx - rx * 0.32f
            val rightHipX = cx + rx * 0.32f
            val leftFootX = cx - rx * 0.46f
            val rightFootX = cx + rx * 0.46f

            drawSolidLeg(canvas, leftHipX, legTopY, leftFootX, groundY - 4f, legW, -1f, legCol, legOut)
            drawSolidLeg(canvas, rightHipX, legTopY, rightFootX, groundY - 4f, legW, 1f, legCol, legOut)

            // Ground shadows
            val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.argb(40, 0, 0, 0)
                style = Paint.Style.FILL
            }
            canvas.drawOval(RectF(leftFootX - rx * 0.28f, groundY - 1f, leftFootX + rx * 0.28f, groundY + 4f), shadowPaint)
            canvas.drawOval(RectF(rightFootX - rx * 0.28f, groundY - 1f, rightFootX + rx * 0.28f, groundY + 4f), shadowPaint)

            // Sneakers
            drawSneaker(canvas, leftFootX, groundY, isLeft = true, rx = rx)
            drawSneaker(canvas, rightFootX, groundY, isLeft = false, rx = rx)

            // 3. Brain Dome
            val cloudPath = Path().apply {
                moveTo(cx, cy - ry * 0.90f)
                cubicTo(cx + rx * 0.15f, cy - ry * 1.08f, cx + rx * 0.38f, cy - ry * 1.08f, cx + rx * 0.50f, cy - ry * 0.88f)
                cubicTo(cx + rx * 0.65f, cy - ry * 0.95f, cx + rx * 0.85f, cy - ry * 0.80f, cx + rx * 0.92f, cy - ry * 0.55f)
                cubicTo(cx + rx * 1.08f, cy - ry * 0.40f, cx + rx * 1.12f, cy - ry * 0.10f, cx + rx * 1.02f, cy + ry * 0.15f)
                cubicTo(cx + rx * 1.12f, cy + ry * 0.30f, cx + rx * 1.05f, cy + ry * 0.55f, cx + rx * 0.88f, cy + ry * 0.68f)
                cubicTo(cx + rx * 0.85f, cy + ry * 0.88f, cx + rx * 0.60f, cy + ry * 0.98f, cx + rx * 0.38f, cy + ry * 0.88f)
                cubicTo(cx + rx * 0.25f, cy + ry * 0.95f, cx + rx * 0.10f, cy + ry * 0.92f, cx, cy + ry * 0.85f)
                cubicTo(cx - rx * 0.10f, cy + ry * 0.92f, cx - rx * 0.25f, cy + ry * 0.95f, cx - rx * 0.38f, cy + ry * 0.88f)
                cubicTo(cx - rx * 0.60f, cy + ry * 0.98f, cx - rx * 0.85f, cy + ry * 0.88f, cx - rx * 0.88f, cy + ry * 0.68f)
                cubicTo(cx - rx * 1.05f, cy + ry * 0.55f, cx - rx * 1.12f, cy + ry * 0.30f, cx - rx * 1.02f, cy + ry * 0.15f)
                cubicTo(cx - rx * 1.12f, cy - ry * 0.10f, cx - rx * 1.08f, cy - ry * 0.40f, cx - rx * 0.92f, cy - ry * 0.55f)
                cubicTo(cx - rx * 0.85f, cy - ry * 0.80f, cx - rx * 0.65f, cy - ry * 0.95f, cx - rx * 0.50f, cy - ry * 0.88f)
                cubicTo(cx - rx * 0.38f, cy - ry * 1.08f, cx - rx * 0.15f, cy - ry * 1.08f, cx, cy - ry * 0.90f)
                close()
            }

            val (c1, c2, c3, outColor) = when (tier) {
                0 -> listOf("#FFDFE6", "#FFB4C4", "#F28DA2", "#B53952")
                1 -> listOf("#FFD8E0", "#F8A8B9", "#E28096", "#A8324A")
                2 -> listOf("#F8CED7", "#E89BA9", "#D27286", "#982A40")
                else -> listOf("#F2C8D2", "#DE9FA9", "#C07684", "#882337")
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

            // 4. Arms & Seamless Cartoon Gloves
            val armW = max(3.0f, rx * 0.24f)
            val leftShoulderX = cx - rx * 0.88f
            val leftShoulderY = cy + ry * 0.20f
            val rightShoulderX = cx + rx * 0.88f
            val rightShoulderY = cy + ry * 0.20f

            when (tier) {
                0 -> {
                    // Fresh: Left wave up, Right arch out & down with fingers pointing straight DOWN
                    val leftHandX = cx - rx * 1.22f
                    val leftHandY = cy - ry * 0.35f
                    val leftElbowX = (leftShoulderX + leftHandX) / 2f - 4f
                    val leftElbowY = (leftShoulderY + leftHandY) / 2f + 4f

                    drawArmTube(canvas, leftShoulderX, leftShoulderY, leftElbowX, leftElbowY, leftHandX, leftHandY, armW, legCol, legOut)
                    val leftAngle = atan2(leftHandY - leftElbowY, leftHandX - leftElbowX)
                    drawSeamlessGlove(canvas, leftHandX, leftHandY, leftAngle, isLeft = true, rx = rx)

                    val rightElbowX = cx + rx * 1.22f
                    val rightElbowY = cy + ry * 0.42f
                    val rightHandX = cx + rx * 1.15f
                    val rightHandY = cy + ry * 0.72f

                    drawArmTube(canvas, rightShoulderX, rightShoulderY, rightElbowX, rightElbowY, rightHandX, rightHandY, armW, legCol, legOut)
                    val rightAngle = (PI / 2.0).toFloat() // Straight DOWN!
                    drawSeamlessGlove(canvas, rightHandX, rightHandY, rightAngle, isLeft = false, rx = rx)
                }
                1 -> {
                    // Tired: Both arms hanging down loosely, fingers down
                    val leftHandX = cx - rx * 1.02f
                    val leftHandY = cy + ry * 0.78f
                    val rightHandX = cx + rx * 1.02f
                    val rightHandY = cy + ry * 0.78f
                    val leftElbowX = leftShoulderX - 1f
                    val leftElbowY = (leftShoulderY + leftHandY) / 2f
                    val rightElbowX = rightShoulderX + 1f
                    val rightElbowY = (rightShoulderY + rightHandY) / 2f

                    drawArmTube(canvas, leftShoulderX, leftShoulderY, leftElbowX, leftElbowY, leftHandX, leftHandY, armW, legCol, legOut)
                    drawArmTube(canvas, rightShoulderX, rightShoulderY, rightElbowX, rightElbowY, rightHandX, rightHandY, armW, legCol, legOut)

                    val leftAngle = atan2(leftHandY - leftElbowY, leftHandX - leftElbowX)
                    val rightAngle = atan2(rightHandY - rightElbowY, rightHandX - rightElbowX)
                    drawSeamlessGlove(canvas, leftHandX, leftHandY, leftAngle, isLeft = true, rx = rx)
                    drawSeamlessGlove(canvas, rightHandX, rightHandY, rightAngle, isLeft = false, rx = rx)
                }
                2 -> {
                    // Heavy: Wide flared elbows gripping temples
                    val leftHandX = cx - rx * 0.88f
                    val leftHandY = cy - ry * 0.12f
                    val rightHandX = cx + rx * 0.88f
                    val rightHandY = cy - ry * 0.12f
                    val leftElbowX = cx - rx * 1.40f
                    val leftElbowY = cy + ry * 0.26f
                    val rightElbowX = cx + rx * 1.40f
                    val rightElbowY = cy + ry * 0.26f

                    drawArmTube(canvas, leftShoulderX, leftShoulderY, leftElbowX, leftElbowY, leftHandX, leftHandY, armW, legCol, legOut)
                    drawArmTube(canvas, rightShoulderX, rightShoulderY, rightElbowX, rightElbowY, rightHandX, rightHandY, armW, legCol, legOut)

                    val leftAngle = atan2(leftHandY - leftElbowY, leftHandX - leftElbowX)
                    val rightAngle = atan2(rightHandY - rightElbowY, rightHandX - rightElbowX)
                    drawSeamlessGlove(canvas, leftHandX, leftHandY, leftAngle, isLeft = true, rx = rx)
                    drawSeamlessGlove(canvas, rightHandX, rightHandY, rightAngle, isLeft = false, rx = rx)
                }
                else -> {
                    // Overloaded: Hands framing trembling face
                    val leftHandX = cx - rx * 0.45f
                    val leftHandY = cy + ry * 0.40f
                    val rightHandX = cx + rx * 0.45f
                    val rightHandY = cy + ry * 0.40f
                    val leftElbowX = cx - rx * 0.85f
                    val leftElbowY = cy + ry * 0.50f
                    val rightElbowX = cx + rx * 0.85f
                    val rightElbowY = cy + ry * 0.50f

                    drawArmTube(canvas, leftShoulderX, leftShoulderY, leftElbowX, leftElbowY, leftHandX, leftHandY, armW, legCol, legOut)
                    drawArmTube(canvas, rightShoulderX, rightShoulderY, rightElbowX, rightElbowY, rightHandX, rightHandY, armW, legCol, legOut)

                    val leftAngle = atan2(leftHandY - leftElbowY, leftHandX - leftElbowX)
                    val rightAngle = atan2(rightHandY - rightElbowY, rightHandX - rightElbowX)
                    drawSeamlessGlove(canvas, leftHandX, leftHandY, leftAngle, isLeft = true, rx = rx)
                    drawSeamlessGlove(canvas, rightHandX, rightHandY, rightAngle, isLeft = false, rx = rx)
                }
            }

            // 5. Gyri walnut folds
            drawGyriFolds(canvas, cx, cy, rx, ry, tier)

            // 6. Face Expressions per Tier
            drawFace(canvas, cx, cy, rx, ry, tier)

            return bitmap
        } catch (_: Exception) {
            return null
        }
    }

    private fun drawSolidLeg(canvas: Canvas, hipX: Float, hipY: Float, footX: Float, footY: Float, width: Float, dir: Float, fillCol: String, strokeCol: String) {
        val halfW = width / 2f
        val path = Path().apply {
            moveTo(hipX - halfW * 1.1f, hipY)
            quadTo(hipX + dir * -2f, (hipY + footY) / 2f, footX - halfW * 0.9f, footY)
            lineTo(footX + halfW * 0.9f, footY)
            quadTo(hipX + halfW * 2.0f + dir * -2f, (hipY + footY) / 2f, hipX + halfW * 1.1f, hipY)
            close()
        }

        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor(fillCol) }
        canvas.drawPath(path, fillPaint)

        val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor(strokeCol)
            style = Paint.Style.STROKE
            strokeWidth = 1.6f
        }
        canvas.drawPath(path, strokePaint)
    }

    private fun drawSneaker(canvas: Canvas, x: Float, y: Float, isLeft: Boolean, rx: Float) {
        val dir = if (isLeft) -1f else 1f
        val len = rx * 0.58f
        val shoeHeight = rx * 0.32f
        val heelX = x - dir * (rx * 0.12f)
        val toeX = x + dir * len
        val ankleY = y - shoeHeight

        val shoeBody = Path().apply {
            moveTo(heelX, y)
            lineTo(heelX, ankleY)
            lineTo(x + dir * (rx * 0.08f), ankleY + 1f)
            lineTo(toeX - dir * (rx * 0.18f), y - shoeHeight * 0.4f)
            lineTo(toeX, y)
            close()
        }

        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#1E293B") }
        canvas.drawPath(shoeBody, fillPaint)

        val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#0F172A")
            style = Paint.Style.STROKE
            strokeWidth = 1.0f
        }
        canvas.drawPath(shoeBody, strokePaint)

        // White Sole
        val whitePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
        val minX = min(heelX, toeX)
        val maxX = max(heelX, toeX)
        val rectF = RectF(minX, y - 2f, maxX, y + 2.5f)
        canvas.drawRoundRect(rectF, 1.5f, 1.5f, whitePaint)
        canvas.drawRoundRect(rectF, 1.5f, 1.5f, strokePaint)

        // Rubber Toe Cap
        val toePath = Path().apply {
            moveTo(toeX - dir * (rx * 0.20f), y)
            quadTo(toeX - dir * (rx * 0.12f), y - shoeHeight * 0.45f, toeX, y)
            close()
        }
        canvas.drawPath(toePath, whitePaint)
        canvas.drawPath(toePath, strokePaint)
    }

    private fun drawArmTube(canvas: Canvas, x1: Float, y1: Float, cxP: Float, cyP: Float, x2: Float, y2: Float, width: Float, fillCol: String, strokeCol: String) {
        val path = Path().apply {
            moveTo(x1, y1)
            quadTo(cxP, cyP, x2, y2)
        }

        val strokeOuter = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor(strokeCol)
            style = Paint.Style.STROKE
            strokeWidth = width + 1.2f
            strokeCap = Paint.Cap.ROUND
        }
        canvas.drawPath(path, strokeOuter)

        val strokeInner = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor(fillCol)
            style = Paint.Style.STROKE
            strokeWidth = width
            strokeCap = Paint.Cap.ROUND
        }
        canvas.drawPath(path, strokeInner)
    }

    private fun drawSeamlessGlove(canvas: Canvas, x: Float, y: Float, angleRad: Float, isLeft: Boolean, rx: Float) {
        canvas.save()
        canvas.translate(x, y)
        canvas.rotate((angleRad * 180f / PI).toFloat())

        val mirrorY = if (isLeft) 1f else -1f
        canvas.scale(1f, mirrorY)

        val scale = rx / 92f
        canvas.scale(scale, scale)

        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
        val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#0F172A")
            style = Paint.Style.STROKE
            strokeWidth = 1.8f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }

        // Wrist Cuff
        val cuffRect = RectF(-4f, -9f, 3f, 9f)
        canvas.drawRoundRect(cuffRect, 3.5f, 3.5f, fillPaint)
        canvas.drawRoundRect(cuffRect, 3.5f, 3.5f, strokePaint)

        // Hand fingers
        val handPath = Path().apply {
            moveTo(3f, 7f)
            lineTo(15f, 7.5f)
            arcTo(RectF(13f, 3.5f, 17.5f, 8f), 90f, -180f, false)
            lineTo(12f, 3.5f)

            lineTo(19f, 3.0f)
            arcTo(RectF(16.5f, -1.6f, 21.5f, 3.2f), 90f, -180f, false)
            lineTo(13f, -1.6f)

            lineTo(17f, -2.2f)
            arcTo(RectF(14.5f, -6.5f, 19.5f, -2.0f), 90f, -180f, false)
            lineTo(9f, -6.5f)

            quadTo(11f, -11f, 14f, -14f)
            arcTo(RectF(10f, -17f, 15f, -12f), -45f, 180f, false)
            quadTo(6f, -15f, 3f, -7.5f)
            close()
        }
        canvas.drawPath(handPath, fillPaint)
        canvas.drawPath(handPath, strokePaint)

        canvas.restore()
    }

    private fun drawGyriFolds(canvas: Canvas, cx: Float, cy: Float, rx: Float, ry: Float, tier: Int) {
        val (foldCol, foldW) = when (tier) {
            0 -> Pair(Color.argb(170, 217, 88, 116), 1.2f)
            1 -> Pair(Color.argb(185, 168, 50, 74), 1.3f)
            2 -> Pair(Color.argb(205, 152, 42, 64), 1.4f)
            else -> Pair(Color.argb(230, 136, 35, 55), 1.5f)
        }

        val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = foldCol
            style = Paint.Style.STROKE
            strokeWidth = foldW
            strokeCap = Paint.Cap.ROUND
        }

        fun curve(x1: Float, y1: Float, cxP: Float, cyP: Float, x2: Float, y2: Float) {
            val p = Path().apply {
                moveTo(cx + rx * x1, cy + ry * y1)
                quadTo(cx + rx * cxP, cy + ry * cyP, cx + rx * x2, cy + ry * y2)
            }
            canvas.drawPath(p, strokePaint)
        }

        curve(0.0f, -0.90f, -0.02f, -0.70f, 0.0f, -0.52f)
        curve(-0.25f, -0.85f, -0.40f, -0.68f, -0.20f, -0.52f)
        curve(-0.55f, -0.80f, -0.70f, -0.60f, -0.50f, -0.45f)
        curve(0.25f, -0.85f, 0.40f, -0.68f, 0.20f, -0.52f)
        curve(0.55f, -0.80f, 0.70f, -0.60f, 0.50f, -0.45f)
        curve(-0.85f, 0.10f, -0.65f, 0.18f, -0.78f, 0.40f)
        curve(0.85f, 0.10f, 0.65f, 0.18f, 0.78f, 0.40f)
    }

    private fun drawFace(canvas: Canvas, cx: Float, cy: Float, rx: Float, ry: Float, tier: Int) {
        val eyeSpacing = rx * 0.34f
        val eyeY = cy + ry * 0.12f
        val leftEyeX = cx - eyeSpacing
        val rightEyeX = cx + eyeSpacing

        val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#0F172A")
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
        }
        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)

        when (tier) {
            0 -> {
                // Fresh Mind
                val eyeW = rx * 0.24f
                val eyeH = ry * 0.42f

                // Scleras
                fillPaint.color = Color.WHITE
                strokePaint.strokeWidth = 1.3f
                val leftRect = RectF(leftEyeX - eyeW / 2f, eyeY - eyeH / 2f, leftEyeX + eyeW / 2f, eyeY + eyeH / 2f)
                val rightRect = RectF(rightEyeX - eyeW / 2f, eyeY - eyeH / 2f, rightEyeX + eyeW / 2f, eyeY + eyeH / 2f)
                canvas.drawOval(leftRect, fillPaint)
                canvas.drawOval(leftRect, strokePaint)
                canvas.drawOval(rightRect, fillPaint)
                canvas.drawOval(rightRect, strokePaint)

                // Pupils
                fillPaint.color = Color.parseColor("#1E293B")
                val pR = eyeW * 0.32f
                canvas.drawCircle(leftEyeX + eyeW * 0.08f, eyeY - eyeH * 0.04f, pR, fillPaint)
                canvas.drawCircle(rightEyeX + eyeW * 0.08f, eyeY - eyeH * 0.04f, pR, fillPaint)

                // Catchlights
                fillPaint.color = Color.WHITE
                canvas.drawCircle(leftEyeX + eyeW * 0.08f - pR * 0.32f, eyeY - eyeH * 0.04f - pR * 0.32f, pR * 0.4f, fillPaint)
                canvas.drawCircle(rightEyeX + eyeW * 0.08f - pR * 0.32f, eyeY - eyeH * 0.04f - pR * 0.32f, pR * 0.4f, fillPaint)

                // Brows
                strokePaint.color = Color.parseColor("#4A101D")
                strokePaint.strokeWidth = 1.4f
                val leftBrow = Path().apply {
                    moveTo(leftEyeX - eyeW * 0.5f, eyeY - eyeH * 0.65f)
                    quadTo(leftEyeX, eyeY - eyeH * 0.88f, leftEyeX + eyeW * 0.5f, eyeY - eyeH * 0.60f)
                }
                canvas.drawPath(leftBrow, strokePaint)

                val rightBrow = Path().apply {
                    moveTo(rightEyeX - eyeW * 0.5f, eyeY - eyeH * 0.60f)
                    quadTo(rightEyeX, eyeY - eyeH * 0.88f, rightEyeX + eyeW * 0.5f, eyeY - eyeH * 0.65f)
                }
                canvas.drawPath(rightBrow, strokePaint)

                // Rosy Blush
                fillPaint.color = Color.argb(85, 255, 46, 99)
                canvas.drawOval(RectF(leftEyeX - eyeW * 0.4f, eyeY + eyeH * 0.50f, leftEyeX + eyeW * 0.1f, eyeY + eyeH * 0.75f), fillPaint)
                canvas.drawOval(RectF(rightEyeX - eyeW * 0.1f, eyeY + eyeH * 0.50f, rightEyeX + eyeW * 0.4f, eyeY + eyeH * 0.75f), fillPaint)

                // Open Clean Smile
                val mouthY = eyeY + ry * 0.36f
                val mouthPath = Path().apply {
                    moveTo(cx - rx * 0.20f, mouthY)
                    quadTo(cx, mouthY + ry * 0.32f, cx + rx * 0.20f, mouthY)
                    close()
                }
                fillPaint.color = Color.parseColor("#2C0B12")
                canvas.drawPath(mouthPath, fillPaint)

                canvas.save()
                canvas.clipPath(mouthPath)
                fillPaint.color = Color.parseColor("#FF6584")
                canvas.drawCircle(cx, mouthY + ry * 0.20f, rx * 0.12f, fillPaint)
                canvas.restore()

                strokePaint.color = Color.parseColor("#0F172A")
                strokePaint.strokeWidth = 1.3f
                canvas.drawPath(mouthPath, strokePaint)

                // Star Sparkle
                drawStar(canvas, cx + rx * 0.88f, cy - ry * 0.80f, max(3.5f, rx * 0.10f), Color.parseColor("#10B981"))
            }
            1 -> {
                // Tired Face
                val eyeW = rx * 0.22f
                val eyeH = ry * 0.38f
                val pR = eyeW * 0.28f

                fun drawSleepyEye(ex: Float) {
                    canvas.save()
                    canvas.clipRect(ex - eyeW, eyeY - 1f, ex + eyeW, eyeY + eyeH)
                    fillPaint.color = Color.WHITE
                    strokePaint.color = Color.parseColor("#0F172A")
                    strokePaint.strokeWidth = 1.2f
                    val rectF = RectF(ex - eyeW / 2f, eyeY - eyeH / 2f, ex + eyeW / 2f, eyeY + eyeH / 2f)
                    canvas.drawOval(rectF, fillPaint)
                    canvas.drawOval(rectF, strokePaint)
                    fillPaint.color = Color.parseColor("#1E293B")
                    canvas.drawCircle(ex, eyeY + 1.8f, pR, fillPaint)
                    fillPaint.color = Color.WHITE
                    canvas.drawCircle(ex - pR * 0.35f, eyeY + 1.8f - pR * 0.35f, pR * 0.38f, fillPaint)
                    canvas.restore()
                }
                drawSleepyEye(leftEyeX)
                drawSleepyEye(rightEyeX)

                // Eyelid line
                strokePaint.color = Color.parseColor("#0F172A")
                strokePaint.strokeWidth = 1.4f
                canvas.drawLine(leftEyeX - eyeW * 0.6f, eyeY - 1f, leftEyeX + eyeW * 0.6f, eyeY + 1.5f, strokePaint)
                canvas.drawLine(rightEyeX - eyeW * 0.6f, eyeY + 1.5f, rightEyeX + eyeW * 0.6f, eyeY - 1f, strokePaint)

                // Under-eye crease
                strokePaint.color = Color.argb(115, 168, 50, 74)
                strokePaint.strokeWidth = 0.9f
                canvas.drawArc(RectF(leftEyeX - eyeW * 0.42f, eyeY + 1f, leftEyeX + eyeW * 0.42f, eyeY + eyeH * 0.5f), 20f, 140f, false, strokePaint)
                canvas.drawArc(RectF(rightEyeX - eyeW * 0.42f, eyeY + 1f, rightEyeX + eyeW * 0.42f, eyeY + eyeH * 0.5f), 20f, 140f, false, strokePaint)

                // Drooping brows
                strokePaint.color = Color.parseColor("#4A1019")
                strokePaint.strokeWidth = 1.3f
                canvas.drawLine(leftEyeX - eyeW * 0.5f, eyeY - eyeH * 0.55f, leftEyeX + eyeW * 0.4f, eyeY - eyeH * 0.35f, strokePaint)
                canvas.drawLine(rightEyeX - eyeW * 0.4f, eyeY - eyeH * 0.35f, rightEyeX + eyeW * 0.5f, eyeY - eyeH * 0.55f, strokePaint)

                // Wavy sigh mouth
                strokePaint.color = Color.parseColor("#0F172A")
                strokePaint.strokeWidth = 1.3f
                val my = eyeY + ry * 0.36f
                val mouthPath = Path().apply {
                    moveTo(cx - rx * 0.14f, my)
                    cubicTo(cx - rx * 0.05f, my - 2f, cx + rx * 0.05f, my + 2f, cx + rx * 0.14f, my)
                }
                canvas.drawPath(mouthPath, strokePaint)
            }
            2 -> {
                // Heavy Squint > <
                val sz = rx * 0.11f
                strokePaint.color = Color.parseColor("#0F172A")
                strokePaint.strokeWidth = 1.5f

                val leftP = Path().apply {
                    moveTo(leftEyeX - sz, eyeY - sz * 0.7f)
                    lineTo(leftEyeX + sz * 0.4f, eyeY)
                    lineTo(leftEyeX - sz, eyeY + sz * 0.7f)
                }
                canvas.drawPath(leftP, strokePaint)

                val rightP = Path().apply {
                    moveTo(rightEyeX + sz, eyeY - sz * 0.7f)
                    lineTo(rightEyeX - sz * 0.4f, eyeY)
                    lineTo(rightEyeX + sz, eyeY + sz * 0.7f)
                }
                canvas.drawPath(rightP, strokePaint)

                // Grimace mouth
                val my = eyeY + ry * 0.36f
                val mouthPath = Path().apply {
                    moveTo(cx - rx * 0.13f, my + 3f)
                    quadTo(cx, my - 4f, cx + rx * 0.13f, my + 3f)
                }
                canvas.drawPath(mouthPath, strokePaint)

                // Single side tear on right cheek
                drawDroppingTear(canvas, cx + eyeSpacing * 0.95f + 2f, eyeY + 4f, 2.6f)
            }
            else -> {
                // Overloaded weeping (╥ ﹏ ╥)
                val eyeW = rx * 0.14f
                strokePaint.color = Color.parseColor("#0F172A")
                strokePaint.strokeWidth = 1.6f

                canvas.drawLine(leftEyeX - eyeW, eyeY, leftEyeX + eyeW, eyeY, strokePaint)
                canvas.drawLine(rightEyeX - eyeW, eyeY, rightEyeX + eyeW, eyeY, strokePaint)

                // ╥ ╥ Tear stream bars
                strokePaint.color = Color.argb(230, 56, 189, 248)
                strokePaint.strokeWidth = 2.0f
                canvas.drawLine(leftEyeX - eyeW * 0.4f, eyeY + 1f, leftEyeX - eyeW * 0.4f, eyeY + ry * 0.32f, strokePaint)
                canvas.drawLine(leftEyeX + eyeW * 0.4f, eyeY + 1f, leftEyeX + eyeW * 0.4f, eyeY + ry * 0.28f, strokePaint)
                canvas.drawLine(rightEyeX - eyeW * 0.4f, eyeY + 1f, rightEyeX - eyeW * 0.4f, eyeY + ry * 0.28f, strokePaint)
                canvas.drawLine(rightEyeX + eyeW * 0.4f, eyeY + 1f, rightEyeX + eyeW * 0.4f, eyeY + ry * 0.32f, strokePaint)

                // Sobbing mouth
                strokePaint.color = Color.parseColor("#0F172A")
                strokePaint.strokeWidth = 1.5f
                val my = eyeY + ry * 0.38f
                val mouthPath = Path().apply {
                    moveTo(cx - rx * 0.15f, my)
                    quadTo(cx - rx * 0.08f, my - 4f, cx, my)
                    quadTo(cx + rx * 0.08f, my - 4f, cx + rx * 0.15f, my)
                }
                canvas.drawPath(mouthPath, strokePaint)
            }
        }
    }

    private fun drawDroppingTear(canvas: Canvas, x: Float, y: Float, radius: Float) {
        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(220, 2, 132, 199)
        }
        val dropPath = Path().apply {
            moveTo(x, y - radius * 1.8f)
            cubicTo(x + radius * 1.1f, y - radius * 0.4f, x + radius * 1.1f, y + radius, x, y + radius)
            cubicTo(x - radius * 1.1f, y + radius, x - radius * 1.1f, y - radius * 0.4f, x, y - radius * 1.8f)
            close()
        }
        canvas.drawPath(dropPath, fillPaint)

        fillPaint.color = Color.argb(200, 255, 255, 255)
        canvas.drawCircle(x - radius * 0.3f, y + radius * 0.2f, radius * 0.3f, fillPaint)
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

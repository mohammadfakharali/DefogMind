package com.defogmind.app

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.*
import android.util.AttributeSet
import android.view.View
import android.view.animation.LinearInterpolator
import kotlin.math.*

class BrainCharacterView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private var tier: Int = 0 // 0: Fresh, 1: Tired, 2: Heavy, 3: Overloaded
    private var animValue: Float = 0f
    private var animator: ValueAnimator? = null

    // Reusable Paints & Paths to avoid allocations in onDraw
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val genericPath = Path()
    private val rectF = RectF()

    init {
        setupAnimator()
    }

    private fun setupAnimator() {
        animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 6000L // 6-second calm cycle
            repeatCount = ValueAnimator.INFINITE
            interpolator = LinearInterpolator()
            addUpdateListener { animation ->
                animValue = animation.animatedValue as Float
                invalidate()
            }
        }
    }

    fun updateTier(newTier: Int) {
        if (tier != newTier) {
            tier = newTier.coerceIn(0, 3)
            invalidate()
        }
    }

    fun startAnimation() {
        if (animator?.isRunning != true) {
            animator?.start()
        }
    }

    fun stopAnimation() {
        animator?.cancel()
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        startAnimation()
    }

    override fun onDetachedFromWindow() {
        stopAnimation()
        super.onDetachedFromWindow()
    }

    override fun onVisibilityChanged(changedView: View, visibility: Int) {
        super.onVisibilityChanged(changedView, visibility)
        if (visibility == VISIBLE) {
            startAnimation()
        } else {
            stopAnimation()
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val w = width.toFloat()
        val h = height.toFloat()
        if (w <= 0 || h <= 0) return

        val domeCenter = PointF(w * 0.50f, h * 0.40f)
        val baseWidthR = w * 0.38f
        val baseHeightR = w * 0.28f

        val scaleTier = when (tier) {
            0 -> 1.00f
            1 -> 0.91f
            2 -> 0.82f
            else -> 0.72f
        }

        var animCenterX = domeCenter.x
        var animCenterY = domeCenter.y
        var animScale = scaleTier

        when (tier) {
            0 -> {
                val bounceY = sin(animValue * 2.0 * PI).toFloat() * (h * 0.02f)
                val breath = 1.0f + 0.02f * sin(animValue * 2.0 * PI).toFloat()
                animCenterY += bounceY
                animScale *= breath
            }
            1 -> {
                animCenterY += sin(animValue * 2.0 * PI).toFloat() * (h * 0.012f)
            }
            2 -> {
                animCenterX += sin(animValue * 6.0 * PI).toFloat() * 1.2f
                animCenterY += cos(animValue * 4.0 * PI).toFloat() * 0.9f
            }
            else -> {
                animCenterX += sin(animValue * 36.0 * PI).toFloat() * 1.4f
                animCenterY += cos(animValue * 30.0 * PI).toFloat() * 0.9f
            }
        }

        val rx = baseWidthR * animScale
        val ry = baseHeightR * animScale

        // 1. Legs and Sneakers
        drawLegsAndSneakers(canvas, animCenterX, animCenterY, rx, ry, h)

        // 2. Main Cloud Brain Body (Light-Pink Palettes)
        drawBrainDome(canvas, animCenterX, animCenterY, rx, ry)

        // 4. Gyri Folds & Walnut
        drawGyriAndWalnut(canvas, animCenterX, animCenterY, rx, ry)

        // 5. Arms and White Cartoon Gloves
        drawArmsAndGloves(canvas, animCenterX, animCenterY, rx, ry)

        // 6. Face
        drawFace(canvas, animCenterX, animCenterY, rx, ry)

        // 7. Status Particles (Sparkles or Dropping Teardrops)
        drawParticles(canvas, animCenterX, animCenterY, rx, ry, h)
    }

    private fun drawLegsAndSneakers(canvas: Canvas, cx: Float, cy: Float, rx: Float, ry: Float, h: Float) {
        val groundY = h * 0.88f
        val legTopY = cy + ry * 0.82f

        val leftHipX = cx - rx * 0.35f
        val rightHipX = cx + rx * 0.35f
        val leftFootX = cx - rx * 0.45f
        val rightFootX = cx + rx * 0.45f

        strokePaint.color = Color.parseColor("#E8637A")
        strokePaint.strokeWidth = max(1.8f, rx * 0.16f)

        // Left Leg
        genericPath.reset()
        genericPath.moveTo(leftHipX, legTopY)
        val leftMidX = leftHipX - (if (tier == 3) 4f else 2f)
        genericPath.quadTo(leftMidX, (legTopY + groundY) / 2f, leftFootX, groundY - 4f)
        canvas.drawPath(genericPath, strokePaint)

        // Right Leg
        genericPath.reset()
        genericPath.moveTo(rightHipX, legTopY)
        val rightMidX = rightHipX + (if (tier == 3) 4f else 2f)
        genericPath.quadTo(rightMidX, (legTopY + groundY) / 2f, rightFootX, groundY - 4f)
        canvas.drawPath(genericPath, strokePaint)

        // Ground shadow
        fillPaint.color = Color.argb(40, 0, 0, 0)
        rectF.set(leftFootX - rx * 0.28f, groundY - 1f, leftFootX + rx * 0.28f, groundY + 3f)
        canvas.drawOval(rectF, fillPaint)
        rectF.set(rightFootX - rx * 0.28f, groundY - 1f, rightFootX + rx * 0.28f, groundY + 3f)
        canvas.drawOval(rectF, fillPaint)

        // Sneakers
        drawSneaker(canvas, leftFootX, groundY, isLeft = true, rx = rx)
        drawSneaker(canvas, rightFootX, groundY, isLeft = false, rx = rx)
    }

    private fun drawSneaker(canvas: Canvas, x: Float, y: Float, isLeft: Boolean, rx: Float) {
        val dir = if (isLeft) -1f else 1f
        val len = rx * 0.58f
        val shoeHeight = rx * 0.32f
        val heelX = x - dir * (rx * 0.12f)
        val toeX = x + dir * len
        val ankleY = y - shoeHeight

        // Dark Canvas Body
        genericPath.reset()
        genericPath.moveTo(heelX, y)
        genericPath.lineTo(heelX, ankleY)
        genericPath.lineTo(x + dir * (rx * 0.08f), ankleY + 1f)
        genericPath.lineTo(toeX - dir * (rx * 0.18f), y - shoeHeight * 0.4f)
        genericPath.lineTo(toeX, y)
        genericPath.close()

        fillPaint.color = Color.parseColor("#1E293B")
        canvas.drawPath(genericPath, fillPaint)

        strokePaint.color = Color.parseColor("#0F172A")
        strokePaint.strokeWidth = 1.0f
        canvas.drawPath(genericPath, strokePaint)

        // White Sole
        fillPaint.color = Color.WHITE
        val minX = min(heelX, toeX)
        val maxX = max(heelX, toeX)
        rectF.set(minX, y - 2f, maxX, y + 2.5f)
        canvas.drawRoundRect(rectF, 1.5f, 1.5f, fillPaint)
        canvas.drawRoundRect(rectF, 1.5f, 1.5f, strokePaint)

        // Rubber Toe Cap
        genericPath.reset()
        genericPath.moveTo(toeX - dir * (rx * 0.20f), y)
        genericPath.quadTo(toeX - dir * (rx * 0.12f), y - shoeHeight * 0.45f, toeX, y)
        genericPath.close()
        canvas.drawPath(genericPath, fillPaint)
        canvas.drawPath(genericPath, strokePaint)
    }

    private fun drawBrainDome(canvas: Canvas, cx: Float, cy: Float, rx: Float, ry: Float) {
        genericPath.reset()
        // Top center dip
        genericPath.moveTo(cx, cy - ry * 0.90f)

        // Top right dome (middle lobe)
        genericPath.cubicTo(cx + rx * 0.15f, cy - ry * 1.08f, cx + rx * 0.38f, cy - ry * 1.08f, cx + rx * 0.50f, cy - ry * 0.88f)
        // Top right-most dome
        genericPath.cubicTo(cx + rx * 0.65f, cy - ry * 0.95f, cx + rx * 0.85f, cy - ry * 0.80f, cx + rx * 0.92f, cy - ry * 0.55f)
        // Upper right side bulge
        genericPath.cubicTo(cx + rx * 1.08f, cy - ry * 0.40f, cx + rx * 1.12f, cy - ry * 0.10f, cx + rx * 1.02f, cy + ry * 0.15f)
        // Mid right side bulge
        genericPath.cubicTo(cx + rx * 1.12f, cy + ry * 0.30f, cx + rx * 1.05f, cy + ry * 0.55f, cx + rx * 0.88f, cy + ry * 0.68f)
        // Lower right bottom bulge
        genericPath.cubicTo(cx + rx * 0.85f, cy + ry * 0.88f, cx + rx * 0.60f, cy + ry * 0.98f, cx + rx * 0.38f, cy + ry * 0.88f)
        // Bottom center right scallop
        genericPath.cubicTo(cx + rx * 0.25f, cy + ry * 0.95f, cx + rx * 0.10f, cy + ry * 0.92f, cx, cy + ry * 0.85f)

        // Bottom center left scallop
        genericPath.cubicTo(cx - rx * 0.10f, cy + ry * 0.92f, cx - rx * 0.25f, cy + ry * 0.95f, cx - rx * 0.38f, cy + ry * 0.88f)
        // Lower left bottom bulge
        genericPath.cubicTo(cx - rx * 0.60f, cy + ry * 0.98f, cx - rx * 0.85f, cy + ry * 0.88f, cx - rx * 0.88f, cy + ry * 0.68f)
        // Mid left side bulge
        genericPath.cubicTo(cx - rx * 1.05f, cy + ry * 0.55f, cx - rx * 1.12f, cy + ry * 0.30f, cx - rx * 1.02f, cy + ry * 0.15f)
        // Upper left side bulge
        genericPath.cubicTo(cx - rx * 1.12f, cy - ry * 0.10f, cx - rx * 1.08f, cy - ry * 0.40f, cx - rx * 0.92f, cy - ry * 0.55f)
        // Top left-most dome
        genericPath.cubicTo(cx - rx * 0.85f, cy - ry * 0.80f, cx - rx * 0.65f, cy - ry * 0.95f, cx - rx * 0.50f, cy - ry * 0.88f)
        // Top left dome (middle lobe)
        genericPath.cubicTo(cx - rx * 0.38f, cy - ry * 1.08f, cx - rx * 0.15f, cy - ry * 1.08f, cx, cy - ry * 0.90f)
        genericPath.close()

        val (c1, c2, c3, outColor) = when (tier) {
            0 -> listOf("#FFDFE6", "#FFB4C4", "#F28DA2", "#B53952")
            1 -> listOf("#FFD8E0", "#F8A8B9", "#E28096", "#A8324A")
            2 -> listOf("#F8CED7", "#E89BA9", "#D27286", "#982A40")
            else -> listOf("#F2C8D2", "#DE9FA9", "#C07684", "#882337")
        }

        fillPaint.shader = LinearGradient(
            cx, cy - ry, cx, cy + ry,
            intArrayOf(Color.parseColor(c1), Color.parseColor(c2), Color.parseColor(c3)),
            floatArrayOf(0.0f, 0.55f, 1.0f),
            Shader.TileMode.CLAMP
        )
        canvas.drawPath(genericPath, fillPaint)
        fillPaint.shader = null

        strokePaint.color = Color.parseColor(outColor)
        strokePaint.strokeWidth = 1.6f
        canvas.drawPath(genericPath, strokePaint)
    }

    private fun drawGyriAndWalnut(canvas: Canvas, cx: Float, cy: Float, rx: Float, ry: Float) {
        val (foldCol, foldW) = when (tier) {
            0 -> Pair(Color.argb(170, 217, 88, 116), 1.2f)
            1 -> Pair(Color.argb(185, 168, 50, 74), 1.3f)
            2 -> Pair(Color.argb(205, 152, 42, 64), 1.4f)
            else -> Pair(Color.argb(230, 136, 35, 55), 1.5f)
        }

        strokePaint.color = foldCol
        strokePaint.strokeWidth = foldW

        fun curve(x1: Float, y1: Float, cxP: Float, cyP: Float, x2: Float, y2: Float) {
            genericPath.reset()
            genericPath.moveTo(cx + rx * x1, cy + ry * y1)
            genericPath.quadTo(cx + rx * cxP, cy + ry * cyP, cx + rx * x2, cy + ry * y2)
            canvas.drawPath(genericPath, strokePaint)
        }

        // Top center cleft
        curve(0.0f, -0.90f, -0.02f, -0.70f, 0.0f, -0.52f)

        // Top-left lobe curves
        curve(-0.25f, -0.85f, -0.40f, -0.68f, -0.20f, -0.52f)
        curve(-0.55f, -0.80f, -0.70f, -0.60f, -0.50f, -0.45f)
        curve(-0.75f, -0.48f, -0.55f, -0.38f, -0.65f, -0.20f)

        // Top-right lobe curves
        curve(0.25f, -0.85f, 0.40f, -0.68f, 0.20f, -0.52f)
        curve(0.55f, -0.80f, 0.70f, -0.60f, 0.50f, -0.45f)
        curve(0.75f, -0.48f, 0.55f, -0.38f, 0.65f, -0.20f)

        // Left side C curves
        curve(-0.85f, 0.10f, -0.65f, 0.18f, -0.78f, 0.40f)
        curve(-0.70f, 0.50f, -0.50f, 0.58f, -0.60f, 0.75f)

        // Right side C curves
        curve(0.85f, 0.10f, 0.65f, 0.18f, 0.78f, 0.40f)
        curve(0.70f, 0.50f, 0.50f, 0.58f, 0.60f, 0.75f)

        // Bottom chin creases
        curve(-0.35f, 0.75f, -0.20f, 0.62f, -0.08f, 0.72f)
        curve(0.35f, 0.75f, 0.20f, 0.62f, 0.08f, 0.72f)

        if (tier >= 2) {
            strokePaint.strokeWidth = 1.1f
            fun line(x1: Float, y1: Float, x2: Float, y2: Float) {
                canvas.drawLine(cx + rx * x1, cy + ry * y1, cx + rx * x2, cy + ry * y2, strokePaint)
            }
            line(-0.40f, -0.60f, -0.20f, -0.35f)
            line(0.20f, -0.35f, 0.40f, -0.60f)
            line(-0.70f, 0.20f, -0.45f, 0.35f)
            line(0.45f, 0.35f, 0.70f, 0.20f)
        }
    }

    private fun drawArmsAndGloves(canvas: Canvas, cx: Float, cy: Float, rx: Float, ry: Float) {
        strokePaint.color = Color.parseColor("#E8637A")
        strokePaint.strokeWidth = max(1.8f, rx * 0.16f)

        val leftShoulderX = cx - rx * 0.88f
        val leftShoulderY = cy + ry * 0.20f
        val rightShoulderX = cx + rx * 0.88f
        val rightShoulderY = cy + ry * 0.20f

        when (tier) {
            0 -> {
                // Waving hand
                val wave = sin(animValue * 4.0 * PI).toFloat() * (ry * 0.15f)
                val leftHandX = cx - rx * 1.25f
                val leftHandY = cy - ry * 0.35f + wave

                genericPath.reset()
                genericPath.moveTo(leftShoulderX, leftShoulderY)
                genericPath.quadTo(cx - rx * 1.15f, cy, leftHandX, leftHandY)
                canvas.drawPath(genericPath, strokePaint)
                drawGlove(canvas, leftHandX, leftHandY, -34f, isOpen = true, rx = rx)

                // Hip fist
                val rightHandX = cx + rx * 1.05f
                val rightHandY = cy + ry * 0.55f
                genericPath.reset()
                genericPath.moveTo(rightShoulderX, rightShoulderY)
                genericPath.quadTo(cx + rx * 1.20f, cy + ry * 0.38f, rightHandX, rightHandY)
                canvas.drawPath(genericPath, strokePaint)
                drawGlove(canvas, rightHandX, rightHandY, 28f, isOpen = false, rx = rx)
            }
            1 -> {
                // Hanging arms
                val leftHandX = cx - rx * 1.05f
                val leftHandY = cy + ry * 0.75f
                val rightHandX = cx + rx * 1.05f
                val rightHandY = cy + ry * 0.75f
                canvas.drawLine(leftShoulderX, leftShoulderY, leftHandX, leftHandY, strokePaint)
                canvas.drawLine(rightShoulderX, rightShoulderY, rightHandX, rightHandY, strokePaint)
                drawGlove(canvas, leftHandX, leftHandY, 12f, isOpen = false, rx = rx)
                drawGlove(canvas, rightHandX, rightHandY, -12f, isOpen = false, rx = rx)
            }
            2 -> {
                // Holding head
                val leftHandX = cx - rx * 0.95f
                val leftHandY = cy - ry * 0.10f
                val rightHandX = cx + rx * 0.95f
                val rightHandY = cy - ry * 0.10f

                genericPath.reset()
                genericPath.moveTo(leftShoulderX, leftShoulderY)
                genericPath.quadTo(cx - rx * 1.22f, cy + ry * 0.05f, leftHandX, leftHandY)
                canvas.drawPath(genericPath, strokePaint)

                genericPath.reset()
                genericPath.moveTo(rightShoulderX, rightShoulderY)
                genericPath.quadTo(cx + rx * 1.22f, cy + ry * 0.05f, rightHandX, rightHandY)
                canvas.drawPath(genericPath, strokePaint)

                drawGlove(canvas, leftHandX, leftHandY, -68f, isOpen = true, rx = rx)
                drawGlove(canvas, rightHandX, rightHandY, 68f, isOpen = true, rx = rx)
            }
            else -> {
                // Trembling sob
                val tr = sin(animValue * 30.0 * PI).toFloat() * (rx * 0.08f)
                val leftHandX = cx - rx * 0.45f + tr
                val leftHandY = cy + ry * 0.40f
                val rightHandX = cx + rx * 0.45f - tr
                val rightHandY = cy + ry * 0.40f

                genericPath.reset()
                genericPath.moveTo(leftShoulderX, leftShoulderY)
                genericPath.quadTo(cx - rx * 0.85f, cy + ry * 0.50f, leftHandX, leftHandY)
                canvas.drawPath(genericPath, strokePaint)

                genericPath.reset()
                genericPath.moveTo(rightShoulderX, rightShoulderY)
                genericPath.quadTo(cx + rx * 0.85f, cy + ry * 0.50f, rightHandX, rightHandY)
                canvas.drawPath(genericPath, strokePaint)

                drawGlove(canvas, leftHandX, leftHandY, -23f, isOpen = false, rx = rx)
                drawGlove(canvas, rightHandX, rightHandY, 23f, isOpen = false, rx = rx)
            }
        }
    }

    private fun drawGlove(canvas: Canvas, x: Float, y: Float, degrees: Float, isOpen: Boolean, rx: Float) {
        canvas.save()
        canvas.translate(x, y)
        canvas.rotate(degrees)

        fillPaint.color = Color.WHITE
        strokePaint.color = Color.parseColor("#0F172A")
        strokePaint.strokeWidth = 1.0f

        val sz = rx * 0.32f
        // Cuff
        rectF.set(-sz * 0.6f, -sz * 0.3f, sz * 0.6f, sz * 0.3f)
        canvas.drawRoundRect(rectF, sz * 0.25f, sz * 0.25f, fillPaint)
        canvas.drawRoundRect(rectF, sz * 0.25f, sz * 0.25f, strokePaint)

        // Hand
        rectF.set(-sz * 0.55f, sz * 0.15f, sz * 0.55f, sz * 1.15f)
        canvas.drawRoundRect(rectF, sz * 0.45f, sz * 0.45f, fillPaint)
        canvas.drawRoundRect(rectF, sz * 0.45f, sz * 0.45f, strokePaint)

        canvas.restore()
    }

    private fun drawFace(canvas: Canvas, cx: Float, cy: Float, rx: Float, ry: Float) {
        val eyeSpacing = rx * 0.34f
        val eyeY = cy + ry * 0.12f
        val leftEyeX = cx - eyeSpacing
        val rightEyeX = cx + eyeSpacing

        when (tier) {
            0 -> {
                // Natural Blink once every 6 seconds (between 0.94 and 0.97)
                val isBlinking = animValue in 0.94f..0.97f
                val eyeW = rx * 0.24f
                val eyeH = ry * 0.42f

                if (isBlinking) {
                    strokePaint.color = Color.parseColor("#0F172A")
                    strokePaint.strokeWidth = 1.6f
                    rectF.set(leftEyeX - eyeW * 0.5f, eyeY - eyeW * 0.5f, leftEyeX + eyeW * 0.5f, eyeY + eyeW * 0.5f)
                    canvas.drawArc(rectF, 180f, 180f, false, strokePaint)
                    rectF.set(rightEyeX - eyeW * 0.5f, eyeY - eyeW * 0.5f, rightEyeX + eyeW * 0.5f, eyeY + eyeW * 0.5f)
                    canvas.drawArc(rectF, 180f, 180f, false, strokePaint)
                } else {
                    // Sclera
                    fillPaint.color = Color.WHITE
                    strokePaint.color = Color.parseColor("#0F172A")
                    strokePaint.strokeWidth = 1.3f

                    rectF.set(leftEyeX - eyeW / 2f, eyeY - eyeH / 2f, leftEyeX + eyeW / 2f, eyeY + eyeH / 2f)
                    canvas.drawOval(rectF, fillPaint)
                    canvas.drawOval(rectF, strokePaint)

                    rectF.set(rightEyeX - eyeW / 2f, eyeY - eyeH / 2f, rightEyeX + eyeW / 2f, eyeY + eyeH / 2f)
                    canvas.drawOval(rectF, fillPaint)
                    canvas.drawOval(rectF, strokePaint)

                    // Pupils
                    fillPaint.color = Color.parseColor("#1E293B")
                    val pR = eyeW * 0.32f
                    canvas.drawCircle(leftEyeX + eyeW * 0.08f, eyeY - eyeH * 0.04f, pR, fillPaint)
                    canvas.drawCircle(rightEyeX + eyeW * 0.08f, eyeY - eyeH * 0.04f, pR, fillPaint)

                    // Catchlight
                    fillPaint.color = Color.WHITE
                    canvas.drawCircle(leftEyeX + eyeW * 0.08f - pR * 0.32f, eyeY - eyeH * 0.04f - pR * 0.32f, pR * 0.4f, fillPaint)
                    canvas.drawCircle(rightEyeX + eyeW * 0.08f - pR * 0.32f, eyeY - eyeH * 0.04f - pR * 0.32f, pR * 0.4f, fillPaint)
                }

                // Brows
                strokePaint.color = Color.parseColor("#4A101D")
                strokePaint.strokeWidth = 1.4f
                genericPath.reset()
                genericPath.moveTo(leftEyeX - eyeW * 0.5f, eyeY - eyeH * 0.65f)
                genericPath.quadTo(leftEyeX, eyeY - eyeH * 0.88f, leftEyeX + eyeW * 0.5f, eyeY - eyeH * 0.60f)
                canvas.drawPath(genericPath, strokePaint)

                genericPath.reset()
                genericPath.moveTo(rightEyeX - eyeW * 0.5f, rightEyeX.let { eyeY - eyeH * 0.60f })
                genericPath.quadTo(rightEyeX, eyeY - eyeH * 0.88f, rightEyeX + eyeW * 0.5f, eyeY - eyeH * 0.65f)
                canvas.drawPath(genericPath, strokePaint)

                // Blush
                fillPaint.color = Color.argb(85, 255, 46, 99)
                rectF.set(leftEyeX - eyeW * 0.4f, eyeY + eyeH * 0.50f, leftEyeX + eyeW * 0.1f, eyeY + eyeH * 0.75f)
                canvas.drawOval(rectF, fillPaint)
                rectF.set(rightEyeX - eyeW * 0.1f, eyeY + eyeH * 0.50f, rightEyeX + eyeW * 0.4f, eyeY + eyeH * 0.75f)
                canvas.drawOval(rectF, fillPaint)

                // Open Smile
                val mouthY = eyeY + ry * 0.36f
                genericPath.reset()
                genericPath.moveTo(cx - rx * 0.20f, mouthY)
                genericPath.quadTo(cx, mouthY + ry * 0.32f, cx + rx * 0.20f, mouthY)
                genericPath.close()

                fillPaint.color = Color.parseColor("#2C0B12")
                canvas.drawPath(genericPath, fillPaint)

                canvas.save()
                canvas.clipPath(genericPath)
                fillPaint.color = Color.parseColor("#FF6584")
                canvas.drawCircle(cx, mouthY + ry * 0.20f, rx * 0.12f, fillPaint)
                canvas.restore()

                strokePaint.color = Color.parseColor("#0F172A")
                strokePaint.strokeWidth = 1.3f
                canvas.drawPath(genericPath, strokePaint)
            }
            1 -> {
                // Tired Face
                val eyeW = rx * 0.22f
                val eyeH = ry * 0.38f
                val isTiredBlink = animValue in 0.93f..0.98f

                if (isTiredBlink) {
                    strokePaint.color = Color.parseColor("#0F172A")
                    strokePaint.strokeWidth = 1.5f
                    canvas.drawLine(leftEyeX - eyeW * 0.5f, eyeY, leftEyeX + eyeW * 0.5f, eyeY, strokePaint)
                    canvas.drawLine(rightEyeX - eyeW * 0.5f, eyeY, rightEyeX + eyeW * 0.5f, eyeY, strokePaint)
                } else {
                    fun drawHalfEye(ex: Float) {
                        canvas.save()
                        canvas.clipRect(ex - eyeW, eyeY - 1f, ex + eyeW, eyeY + eyeH)
                        fillPaint.color = Color.WHITE
                        strokePaint.color = Color.parseColor("#0F172A")
                        strokePaint.strokeWidth = 1.2f
                        rectF.set(ex - eyeW / 2f, eyeY - eyeH / 2f, ex + eyeW / 2f, eyeY + eyeH / 2f)
                        canvas.drawOval(rectF, fillPaint)
                        canvas.drawOval(rectF, strokePaint)
                        fillPaint.color = Color.parseColor("#1E293B")
                        canvas.drawCircle(ex, eyeY + 2f, eyeW * 0.28f, fillPaint)
                        canvas.restore()
                    }
                    drawHalfEye(leftEyeX)
                    drawHalfEye(rightEyeX)

                    strokePaint.color = Color.parseColor("#0F172A")
                    strokePaint.strokeWidth = 1.4f
                    canvas.drawLine(leftEyeX - eyeW * 0.6f, eyeY - 1f, leftEyeX + eyeW * 0.6f, eyeY + 1.5f, strokePaint)
                    canvas.drawLine(rightEyeX - eyeW * 0.6f, eyeY + 1.5f, rightEyeX + eyeW * 0.6f, eyeY - 1f, strokePaint)
                }

                // Wavy sigh mouth
                strokePaint.color = Color.parseColor("#0F172A")
                strokePaint.strokeWidth = 1.3f
                val my = eyeY + ry * 0.36f
                genericPath.reset()
                genericPath.moveTo(cx - rx * 0.14f, my)
                genericPath.cubicTo(cx - rx * 0.05f, my - 2f, cx + rx * 0.05f, my + 2f, cx + rx * 0.14f, my)
                canvas.drawPath(genericPath, strokePaint)
            }
            2 -> {
                // Heavy Squint > <
                val sz = rx * 0.11f
                strokePaint.color = Color.parseColor("#0F172A")
                strokePaint.strokeWidth = 1.5f

                genericPath.reset()
                genericPath.moveTo(leftEyeX - sz, eyeY - sz * 0.7f)
                genericPath.lineTo(leftEyeX + sz * 0.4f, eyeY)
                genericPath.lineTo(leftEyeX - sz, eyeY + sz * 0.7f)
                canvas.drawPath(genericPath, strokePaint)

                genericPath.reset()
                genericPath.moveTo(rightEyeX + sz, eyeY - sz * 0.7f)
                genericPath.lineTo(rightEyeX - sz * 0.4f, eyeY)
                genericPath.lineTo(rightEyeX + sz, eyeY + sz * 0.7f)
                canvas.drawPath(genericPath, strokePaint)

                // Grimace mouth
                val my = eyeY + ry * 0.36f
                genericPath.reset()
                genericPath.moveTo(cx - rx * 0.13f, my + 3f)
                genericPath.quadTo(cx, my - 4f, cx + rx * 0.13f, my + 3f)
                canvas.drawPath(genericPath, strokePaint)
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
                genericPath.reset()
                genericPath.moveTo(cx - rx * 0.15f, my)
                genericPath.quadTo(cx - rx * 0.08f, my - 4f, cx, my)
                genericPath.quadTo(cx + rx * 0.08f, my - 4f, cx + rx * 0.15f, my)
                canvas.drawPath(genericPath, strokePaint)
            }
        }
    }

    private fun drawParticles(canvas: Canvas, cx: Float, cy: Float, rx: Float, ry: Float, h: Float) {
        val eyeSpacing = rx * 0.34f
        val eyeY = cy + ry * 0.12f

        when (tier) {
            0 -> {
                // Sparkle
                val pulse = (sin(animValue * 2.0 * PI) * 0.5 + 0.5).toFloat()
                fillPaint.color = Color.argb((180 * pulse).toInt(), 16, 185, 129)
                canvas.drawCircle(cx + rx * 0.85f, cy - ry * 0.80f, 3f * pulse, fillPaint)
                canvas.drawCircle(cx - rx * 0.80f, cy - ry * 0.70f, 2.5f * pulse, fillPaint)
            }
            1 -> {
                // Stage 2: Single teardrop below right eye, vanishes completely before bottom
                val phase = (animValue * 1.5f) % 1.0f
                drawDroppingTear(
                    canvas,
                    startX = cx + eyeSpacing * 0.95f,
                    startY = eyeY + ry * 0.22f,
                    totalDistance = ry * 0.50f,
                    phase = phase,
                    maxRadius = 2.4f
                )
            }
            2 -> {
                // Stage 3: Teardrops below BOTH eyes, staggered, vanishing before bottom
                val phaseLeft = (animValue * 1.6f) % 1.0f
                val phaseRight = ((animValue + 0.45f) * 1.6f) % 1.0f
                drawDroppingTear(
                    canvas,
                    startX = cx - eyeSpacing * 0.95f,
                    startY = eyeY + ry * 0.22f,
                    totalDistance = ry * 0.55f,
                    phase = phaseLeft,
                    maxRadius = 2.6f
                )
                drawDroppingTear(
                    canvas,
                    startX = cx + eyeSpacing * 0.95f,
                    startY = eyeY + ry * 0.22f,
                    totalDistance = ry * 0.55f,
                    phase = phaseRight,
                    maxRadius = 2.6f
                )
            }
            3 -> {
                // Stage 4: Continuous weeping drops
                for (i in 0..3) {
                    val phase = (animValue * 2.8f + i * 0.25f) % 1.0f
                    val isLeft = i % 2 == 0
                    val sx = cx + (if (isLeft) -eyeSpacing else eyeSpacing) + (if (i >= 2) (if (isLeft) -3f else 3f) else 0f)
                    drawDroppingTear(
                        canvas,
                        startX = sx,
                        startY = eyeY + ry * 0.25f,
                        totalDistance = h * 0.42f,
                        phase = phase,
                        maxRadius = 2.6f
                    )
                }
            }
        }
    }

    private fun drawDroppingTear(canvas: Canvas, startX: Float, startY: Float, totalDistance: Float, phase: Float, maxRadius: Float) {
        if (phase > 0.72f) return // 28% of cycle is an empty pause (vanished)

        val p = phase / 0.72f
        val tearY = startY + p * totalDistance

        val alpha = when {
            p < 0.15f -> p / 0.15f
            p < 0.50f -> 1.0f
            else -> max(0f, (1.0f - p) / 0.50f)
        }

        if (alpha <= 0.01f) return

        val radius = maxRadius * (0.65f + 0.35f * p)

        // Drop
        fillPaint.color = Color.argb((alpha * 220).toInt(), 2, 132, 199)
        genericPath.reset()
        genericPath.moveTo(startX, tearY - radius * 1.8f)
        genericPath.cubicTo(
            startX + radius * 1.1f, tearY - radius * 0.4f,
            startX + radius * 1.1f, tearY + radius,
            startX, tearY + radius
        )
        genericPath.cubicTo(
            startX - radius * 1.1f, tearY + radius,
            startX - radius * 1.1f, tearY - radius * 0.4f,
            startX, tearY - radius * 1.8f
        )
        genericPath.close()
        canvas.drawPath(genericPath, fillPaint)

        // Shine
        fillPaint.color = Color.argb((alpha * 200).toInt(), 255, 255, 255)
        canvas.drawCircle(startX - radius * 0.3f, tearY + radius * 0.2f, radius * 0.3f, fillPaint)
    }
}


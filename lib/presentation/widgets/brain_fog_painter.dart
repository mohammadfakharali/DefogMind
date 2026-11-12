import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/fog_calculator.dart';
import '../../core/theme/app_theme.dart';

class BrainFogVisualizer extends StatefulWidget {
  final double fogPercentage;
  final FogTier tier;
  final double size;

  const BrainFogVisualizer({
    super.key,
    required this.fogPercentage,
    required this.tier,
    this.size = 280,
  });

  @override
  State<BrainFogVisualizer> createState() => _BrainFogVisualizerState();
}

class _BrainFogVisualizerState extends State<BrainFogVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: BrainFogPainter(
            fogPercentage: widget.fogPercentage,
            tier: widget.tier,
            animationValue: _controller.value,
          ),
        );
      },
    );
  }
}

class BrainFogPainter extends CustomPainter {
  final double fogPercentage;
  final FogTier tier;
  final double animationValue;

  BrainFogPainter({
    required this.fogPercentage,
    required this.tier,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;

    // Outer subtle ambient glow
    _drawAmbientAura(canvas, center, radius);

    // Stylized Geometric / Vector Brain Gyri
    _drawBrainHemispheres(canvas, center, radius);

    // Fog & Particle Haze Layers based on Tier
    if (tier.level >= 1) {
      _drawFloatingParticles(canvas, center, radius);
    }
    if (tier.level >= 2) {
      _drawDenseTangledScribbles(canvas, center, radius);
    }
    if (tier.level >= 3) {
      _drawGlitchSludgeOverlay(canvas, center, radius);
    }
  }

  void _drawAmbientAura(Canvas canvas, Offset center, double radius) {
    final Color auraColor;
    switch (tier) {
      case FogTier.cleanMind:
        auraColor = AppTheme.mint.withValues(alpha: 0.18 + 0.08 * sin(animationValue * 2 * pi));
        break;
      case FogTier.mildHaze:
        auraColor = AppTheme.warningAmber.withValues(alpha: 0.20 + 0.06 * sin(animationValue * 2 * pi));
        break;
      case FogTier.denseFog:
      case FogTier.sludgeGlitch:
        auraColor = AppTheme.glitchCoral.withValues(alpha: 0.25 + 0.10 * sin(animationValue * 4 * pi));
        break;
    }

    final paint = Paint()
      ..color = auraColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32);

    canvas.drawCircle(center, radius * 0.9, paint);
  }

  void _drawBrainHemispheres(Canvas canvas, Offset center, double radius) {
    final Color strokeColor;
    switch (tier) {
      case FogTier.cleanMind:
        strokeColor = AppTheme.mint;
        break;
      case FogTier.mildHaze:
        strokeColor = AppTheme.warningAmber;
        break;
      case FogTier.denseFog:
        strokeColor = const Color(0xFFC084FC); // Tangled violet-amber
        break;
      case FogTier.sludgeGlitch:
        strokeColor = AppTheme.glitchCoral;
        break;
    }

    final brainPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final pulse = 1.0 + 0.03 * sin(animationValue * 2 * pi);

    // Left Hemisphere Outline
    final leftPath = Path();
    final leftCenter = Offset(center.dx - 18, center.dy);
    _buildHemispherePath(leftPath, leftCenter, radius * pulse, isLeft: true);
    canvas.drawPath(leftPath, brainPaint);

    // Right Hemisphere Outline
    final rightPath = Path();
    final rightCenter = Offset(center.dx + 18, center.dy);
    _buildHemispherePath(rightPath, rightCenter, radius * pulse, isLeft: false);
    canvas.drawPath(rightPath, brainPaint);

    // Geometric Gyri & Sulci (Neural folds)
    final foldPaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    _drawFolds(canvas, leftCenter, radius * 0.75, foldPaint, isLeft: true);
    _drawFolds(canvas, rightCenter, radius * 0.75, foldPaint, isLeft: false);
  }

  void _buildHemispherePath(Path path, Offset center, double r, {required bool isLeft}) {
    final double dir = isLeft ? -1.0 : 1.0;

    path.moveTo(center.dx, center.dy - r * 0.85);

    // Top lobe
    path.cubicTo(
      center.dx + dir * r * 0.55, center.dy - r * 0.95,
      center.dx + dir * r * 0.95, center.dy - r * 0.45,
      center.dx + dir * r * 0.90, center.dy - r * 0.10,
    );

    // Temporal lobe
    path.cubicTo(
      center.dx + dir * r * 1.05, center.dy + r * 0.35,
      center.dx + dir * r * 0.70, center.dy + r * 0.85,
      center.dx + dir * r * 0.25, center.dy + r * 0.90,
    );

    // Brain stem curve back to center
    path.cubicTo(
      center.dx + dir * r * 0.10, center.dy + r * 0.60,
      center.dx, center.dy + r * 0.40,
      center.dx, center.dy - r * 0.85,
    );
  }

  void _drawFolds(Canvas canvas, Offset center, double r, Paint paint, {required bool isLeft}) {
    final double dir = isLeft ? -1.0 : 1.0;
    final path = Path();

    // Internal labyrinth curves
    path.moveTo(center.dx + dir * r * 0.3, center.dy - r * 0.6);
    path.quadraticBezierTo(
      center.dx + dir * r * 0.7, center.dy - r * 0.4,
      center.dx + dir * r * 0.4, center.dy - r * 0.1,
    );
    path.quadraticBezierTo(
      center.dx + dir * r * 0.8, center.dy + r * 0.1,
      center.dx + dir * r * 0.3, center.dy + r * 0.4,
    );

    canvas.drawPath(path, paint);
  }

  void _drawFloatingParticles(Canvas canvas, Offset center, double radius) {
    final random = Random(42);
    final count = tier == FogTier.mildHaze ? 18 : 36;
    final particlePaint = Paint()
      ..color = (tier == FogTier.mildHaze ? AppTheme.warningAmber : AppTheme.glitchCoral).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final dist = (random.nextDouble() * radius * 0.85);
      final speed = 1.0 + random.nextDouble() * 2.0;
      final currentAngle = angle + (animationValue * speed * 2 * pi * 0.2);

      final pX = center.dx + cos(currentAngle) * dist;
      final pY = center.dy + sin(currentAngle) * dist;
      final pRadius = 2.0 + random.nextDouble() * 3.5;

      canvas.drawCircle(Offset(pX, pY), pRadius, particlePaint);
    }
  }

  void _drawDenseTangledScribbles(Canvas canvas, Offset center, double radius) {
    final scribblePaint = Paint()
      ..color = AppTheme.glitchCoral.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    final random = Random(101);

    for (int i = 0; i < 14; i++) {
      final startAngle = random.nextDouble() * 2 * pi;
      final startDist = random.nextDouble() * radius * 0.7;
      final p1 = Offset(center.dx + cos(startAngle) * startDist, center.dy + sin(startAngle) * startDist);

      final endAngle = startAngle + pi * 0.6;
      final endDist = random.nextDouble() * radius * 0.7;
      final p2 = Offset(center.dx + cos(endAngle) * endDist, center.dy + sin(endAngle) * endDist);

      path.moveTo(p1.dx, p1.dy);
      path.quadraticBezierTo(
        center.dx + (random.nextDouble() - 0.5) * radius * 0.5,
        center.dy + (random.nextDouble() - 0.5) * radius * 0.5,
        p2.dx,
        p2.dy,
      );
    }
    canvas.drawPath(path, scribblePaint);
  }

  void _drawGlitchSludgeOverlay(Canvas canvas, Offset center, double radius) {
    // Red glitch horizontal tear lines
    final glitchPaint = Paint()
      ..color = AppTheme.glitchCoral.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final jitter = sin(animationValue * 20 * pi);

    for (double y = center.dy - radius * 0.6; y <= center.dy + radius * 0.6; y += 30) {
      final xStart = center.dx - radius * 0.7 + (jitter * 8);
      final xEnd = center.dx + radius * 0.7 - (jitter * 8);
      canvas.drawLine(Offset(xStart, y), Offset(xEnd, y), glitchPaint);
    }
  }

  @override
  bool shouldRepaint(covariant BrainFogPainter oldDelegate) {
    return oldDelegate.fogPercentage != fogPercentage ||
        oldDelegate.tier != tier ||
        oldDelegate.animationValue != animationValue;
  }
}


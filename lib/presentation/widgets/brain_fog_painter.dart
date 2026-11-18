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
    this.size = 240,
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
    // 6.0 second natural cycle: gives calm, natural breathing and spaced-out blinking
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
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
    final w = size.width;
    final h = size.height;

    // Center of the main brain dome
    final domeCenter = Offset(w * 0.50, h * 0.40);
    final baseWidthR = w * 0.38;
    final baseHeightR = w * 0.28;

    // Shrink progression: Plump fresh brain -> slight deflate -> tighter -> dry walnut
    final double scaleTier;
    switch (tier) {
      case FogTier.cleanMind:
        scaleTier = 1.00;
        break;
      case FogTier.mildHaze:
        scaleTier = 0.91;
        break;
      case FogTier.denseFog:
        scaleTier = 0.82;
        break;
      case FogTier.sludgeGlitch:
        scaleTier = 0.72; // Shriveled walnut scale
        break;
    }

    // Dynamic animation offsets (gentle bounce, bob, wobble, or shudder)
    Offset animatedCenter = domeCenter;
    double animatedScale = scaleTier;

    if (tier == FogTier.cleanMind) {
      final bounceY = sin(animationValue * 2 * pi) * 4.0;
      final breath = 1.0 + 0.02 * sin(animationValue * 2 * pi);
      animatedCenter = Offset(domeCenter.dx, domeCenter.dy + bounceY);
      animatedScale = scaleTier * breath;
    } else if (tier == FogTier.mildHaze) {
      final bobY = sin(animationValue * 2 * pi) * 2.5;
      animatedCenter = Offset(domeCenter.dx, domeCenter.dy + bobY);
    } else if (tier == FogTier.denseFog) {
      final wobbleX = sin(animationValue * 6 * pi) * 1.5;
      final wobbleY = cos(animationValue * 4 * pi) * 1.2;
      animatedCenter = Offset(domeCenter.dx + wobbleX, domeCenter.dy + wobbleY);
    } else {
      // Overloaded: rapid shivering shudder
      final shudderX = sin(animationValue * 36 * pi) * 1.8;
      final shudderY = cos(animationValue * 30 * pi) * 1.2;
      animatedCenter = Offset(domeCenter.dx + shudderX, domeCenter.dy + shudderY);
    }

    final rx = baseWidthR * animatedScale;
    final ry = baseHeightR * animatedScale;

    // 0. Ambient soft background aura matching status
    _drawAmbientAura(canvas, animatedCenter, rx * 1.15);

    // 1. Legs and Cool Sneakers (drawn behind brain)
    _drawLegsAndSneakers(canvas, animatedCenter, rx, ry, h);

    // 2. Main Cloud Brain Body (Cerebrum) with beautiful realistic light-pink brain colors
    _drawBrainDome(canvas, animatedCenter, rx, ry);

    // 4. Intricate Brain Gyri / Folds & Walnut Creases
    _drawGyriFoldsAndWalnutTexture(canvas, animatedCenter, rx, ry);

    // 5. Arms and White Cartoon Gloves
    _drawArmsAndGloves(canvas, animatedCenter, rx, ry);

    // 6. Expressive Face (Spaced-out natural blink, big eyes, smile, blush)
    _drawExpressiveFace(canvas, animatedCenter, rx, ry);

    // 7. Emotional Particles: Sparkles, Sweat drops, or Streaming Teardrops
    _drawStatusParticles(canvas, animatedCenter, rx, ry, h);
  }

  // --- AMBIENT AURA ---
  void _drawAmbientAura(Canvas canvas, Offset center, double radius) {
    final Color auraColor;
    switch (tier) {
      case FogTier.cleanMind:
        auraColor = AppTheme.mint.withValues(alpha: 0.16 + 0.05 * sin(animationValue * 2 * pi));
        break;
      case FogTier.mildHaze:
        auraColor = AppTheme.warningAmber.withValues(alpha: 0.18 + 0.04 * sin(animationValue * 2 * pi));
        break;
      case FogTier.denseFog:
        auraColor = const Color(0xFFFB923C).withValues(alpha: 0.22 + 0.05 * sin(animationValue * 4 * pi));
        break;
      case FogTier.sludgeGlitch:
        auraColor = AppTheme.glitchCoral.withValues(alpha: 0.26 + 0.07 * sin(animationValue * 8 * pi));
        break;
    }

    final paint = Paint()
      ..color = auraColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);

    canvas.drawCircle(center, radius, paint);
  }

  // --- LEGS AND CARTOON SNEAKERS ---
  void _drawLegsAndSneakers(Canvas canvas, Offset center, double rx, double ry, double totalHeight) {
    final groundY = totalHeight * 0.88;
    final legTopY = center.dy + ry * 0.82;

    final leftHipX = center.dx - rx * 0.35;
    final rightHipX = center.dx + rx * 0.35;

    final leftFootX = center.dx - rx * 0.45;
    final rightFootX = center.dx + rx * 0.45;

    final Color legColor;
    final Color legOutline;
    switch (tier) {
      case FogTier.cleanMind:
        legColor = const Color(0xFFD95874);
        legOutline = const Color(0xFFB53952);
        break;
      case FogTier.mildHaze:
        legColor = const Color(0xFFCA5A70);
        legOutline = const Color(0xFFA8324A);
        break;
      case FogTier.denseFog:
        legColor = const Color(0xFFB8485E);
        legOutline = const Color(0xFF982A40);
        break;
      case FogTier.sludgeGlitch:
        legColor = const Color(0xFFA0384E);
        legOutline = const Color(0xFF882337);
        break;
    }

    const legWidth = 11.0;
    _drawSolidLeg(canvas, leftHipX, legTopY, leftFootX, groundY - 14, legWidth, -1.0, legColor, legOutline);
    _drawSolidLeg(canvas, rightHipX, legTopY, rightFootX, groundY - 14, legWidth, 1.0, legColor, legOutline);

    // Ground shadows
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromCenter(center: Offset(leftFootX, groundY + 4), width: 34, height: 8), shadowPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(rightFootX, groundY + 4), width: 34, height: 8), shadowPaint);

    // Draw Sneakers
    _drawSneaker(canvas, Offset(leftFootX, groundY), isLeft: true);
    _drawSneaker(canvas, Offset(rightFootX, groundY), isLeft: false);
  }

  void _drawSolidLeg(Canvas canvas, double hipX, double hipY, double footX, double footY, double width, double dir, Color legColor, Color legOutline) {
    final halfW = width / 2;
    final path = Path();
    path.moveTo(hipX - halfW * 1.1, hipY);
    path.quadraticBezierTo(hipX + dir * -2, (hipY + footY) / 2, footX - halfW * 0.9, footY);
    path.lineTo(footX + halfW * 0.9, footY);
    path.quadraticBezierTo(hipX + halfW * 2.0 + dir * -2, (hipY + footY) / 2, hipX + halfW * 1.1, hipY);
    path.close();

    final fillPaint = Paint()
      ..color = legColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = legOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);
  }

  void _drawSneaker(Canvas canvas, Offset footPos, {required bool isLeft}) {
    final double dir = isLeft ? -1.0 : 1.0;
    const shoeLength = 32.0;
    const shoeHeight = 16.0;

    final shoeBody = Path();
    final heelX = footPos.dx - dir * 6;
    final toeX = footPos.dx + dir * shoeLength;
    final ankleY = footPos.dy - shoeHeight;

    shoeBody.moveTo(heelX, footPos.dy);
    shoeBody.lineTo(heelX, ankleY);
    shoeBody.lineTo(footPos.dx + dir * 4, ankleY + 2);
    shoeBody.lineTo(toeX - dir * 8, footPos.dy - 6);
    shoeBody.lineTo(toeX, footPos.dy);
    shoeBody.close();

    final canvasPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    canvas.drawPath(shoeBody, canvasPaint);

    final strokePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(shoeBody, strokePaint);

    // White Rubber Sole
    final soleRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        isLeft ? toeX : heelX,
        footPos.dy - 3,
        isLeft ? heelX : toeX,
        footPos.dy + 3,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(soleRect, Paint()..color = Colors.white);
    canvas.drawRRect(soleRect, strokePaint);

    // Sole dark line
    canvas.drawLine(
      Offset(isLeft ? toeX : heelX, footPos.dy),
      Offset(isLeft ? heelX : toeX, footPos.dy),
      Paint()..color = const Color(0xFF0F172A)..strokeWidth = 1.0,
    );

    // White Rubber Toe Cap
    final toeCap = Path();
    toeCap.moveTo(toeX - dir * 10, footPos.dy);
    toeCap.quadraticBezierTo(toeX - dir * 7, footPos.dy - 7, toeX, footPos.dy);
    toeCap.close();
    canvas.drawPath(toeCap, Paint()..color = Colors.white);
    canvas.drawPath(toeCap, strokePaint);

    // White Shoe Laces
    final lacePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final laceTop = Offset(footPos.dx + dir * 1, ankleY + 4);
    final laceMid = Offset(footPos.dx + dir * 7, ankleY + 8);
    canvas.drawLine(laceTop, laceMid, lacePaint);

    // Little lace loops
    canvas.drawCircle(laceTop + Offset(-dir * 2, -2), 2.2, lacePaint);
    canvas.drawCircle(laceTop + Offset(dir * 2, -1), 2.0, lacePaint);
  }

  // --- BRAIN DOME (Realistic Light-Pink Palettes) ---
  void _drawBrainDome(Canvas canvas, Offset center, double rx, double ry) {
    final domePath = _createAnatomicalDomePath(center, rx, ry);

    final List<Color> gradientColors;
    final Color outlineColor;

    switch (tier) {
      case FogTier.cleanMind:
        // STAGE 1: Beautiful fresh light-pink brain (soft highlight -> fresh light pink -> soft rose shading)
        gradientColors = [
          const Color(0xFFFFDFE6), // delicate creamy light-pink highlight
          const Color(0xFFFFB4C4), // fresh, clean baby light pink
          const Color(0xFFF28DA2), // soft warm rose underside
        ];
        outlineColor = const Color(0xFFB53952);
        break;
      case FogTier.mildHaze:
        // STAGE 2: Gentle tired light-pink
        gradientColors = [
          const Color(0xFFFFD8E0),
          const Color(0xFFF8A8B9),
          const Color(0xFFE28096),
        ];
        outlineColor = const Color(0xFFA8324A);
        break;
      case FogTier.denseFog:
        // STAGE 3: Realistic stressed light pastel-pink (NOT muddy/brown!)
        gradientColors = [
          const Color(0xFFF8CED7),
          const Color(0xFFE89BA9),
          const Color(0xFFD27286),
        ];
        outlineColor = const Color(0xFF982A40);
        break;
      case FogTier.sludgeGlitch:
        // STAGE 4: Realistic dehydrated pale ice-rose walnut tone (clean, NOT dirty/dark!)
        gradientColors = [
          const Color(0xFFF2C8D2),
          const Color(0xFFDE9FA9),
          const Color(0xFFC07684),
        ];
        outlineColor = const Color(0xFF882337);
        break;
    }

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: gradientColors,
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCenter(center: center, width: rx * 2.2, height: ry * 2.2))
      ..style = PaintingStyle.fill;

    canvas.drawPath(domePath, fillPaint);

    // Outer contour stroke
    final strokePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(domePath, strokePaint);
  }

  Path _createAnatomicalDomePath(Offset center, double rx, double ry) {
    final path = Path();
    final cx = center.dx;
    final cy = center.dy;

    // Top center dip
    path.moveTo(cx, cy - ry * 0.90);

    // Top right dome (middle lobe)
    path.cubicTo(cx + rx * 0.15, cy - ry * 1.08, cx + rx * 0.38, cy - ry * 1.08, cx + rx * 0.50, cy - ry * 0.88);
    // Top right-most dome
    path.cubicTo(cx + rx * 0.65, cy - ry * 0.95, cx + rx * 0.85, cy - ry * 0.80, cx + rx * 0.92, cy - ry * 0.55);
    // Upper right side bulge
    path.cubicTo(cx + rx * 1.08, cy - ry * 0.40, cx + rx * 1.12, cy - ry * 0.10, cx + rx * 1.02, cy + ry * 0.15);
    // Mid right side bulge
    path.cubicTo(cx + rx * 1.12, cy + ry * 0.30, cx + rx * 1.05, cy + ry * 0.55, cx + rx * 0.88, cy + ry * 0.68);
    // Lower right bottom bulge
    path.cubicTo(cx + rx * 0.85, cy + ry * 0.88, cx + rx * 0.60, cy + ry * 0.98, cx + rx * 0.38, cy + ry * 0.88);
    // Bottom center right scallop
    path.cubicTo(cx + rx * 0.25, cy + ry * 0.95, cx + rx * 0.10, cy + ry * 0.92, cx, cy + ry * 0.85);

    // Bottom center left scallop
    path.cubicTo(cx - rx * 0.10, cy + ry * 0.92, cx - rx * 0.25, cy + ry * 0.95, cx - rx * 0.38, cy + ry * 0.88);
    // Lower left bottom bulge
    path.cubicTo(cx - rx * 0.60, cy + ry * 0.98, cx - rx * 0.85, cy + ry * 0.88, cx - rx * 0.88, cy + ry * 0.68);
    // Mid left side bulge
    path.cubicTo(cx - rx * 1.05, cy + ry * 0.55, cx - rx * 1.12, cy + ry * 0.30, cx - rx * 1.02, cy + ry * 0.15);
    // Upper left side bulge
    path.cubicTo(cx - rx * 1.12, cy - ry * 0.10, cx - rx * 1.08, cy - ry * 0.40, cx - rx * 0.92, cy - ry * 0.55);
    // Top left-most dome
    path.cubicTo(cx - rx * 0.85, cy - ry * 0.80, cx - rx * 0.65, cy - ry * 0.95, cx - rx * 0.50, cy - ry * 0.88);
    // Top left dome (middle lobe)
    path.cubicTo(cx - rx * 0.38, cy - ry * 1.08, cx - rx * 0.15, cy - ry * 1.08, cx, cy - ry * 0.90);

    path.close();
    return path;
  }

  // --- GYRI FOLDS & WALNUT TEXTURE ---
  void _drawGyriFoldsAndWalnutTexture(Canvas canvas, Offset center, double rx, double ry) {
    final Color foldColor;
    final double foldWidth;

    switch (tier) {
      case FogTier.cleanMind:
        foldColor = const Color(0xFFD95874).withValues(alpha: 0.80);
        foldWidth = 1.9;
        break;
      case FogTier.mildHaze:
        foldColor = const Color(0xFFA8324A).withValues(alpha: 0.82);
        foldWidth = 2.0;
        break;
      case FogTier.denseFog:
        foldColor = const Color(0xFF982A40).withValues(alpha: 0.88);
        foldWidth = 2.1;
        break;
      case FogTier.sludgeGlitch:
        foldColor = const Color(0xFF882337).withValues(alpha: 0.92);
        foldWidth = 2.3;
        break;
    }

    final foldPaint = Paint()
      ..color = foldColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = foldWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Top center cleft
    _drawGyriCurve(canvas, foldPaint, center, rx, ry, 0.0, -0.90, -0.02, -0.70, 0.0, -0.52);

    // Top-left lobe curves
    _drawGyriCurve(canvas, foldPaint, center, rx, ry, -0.25, -0.85, -0.40, -0.68, -0.20, -0.52);
    _drawGyriCurve(canvas, foldPaint, center, rx, ry, -0.55, -0.80, -0.70, -0.60, -0.50, -0.45);
    _drawGyriCurve(canvas, foldPaint, center, rx, ry, -0.75, -0.48, -0.55, -0.38, -0.65, -0.20);

    // Top-right lobe curves
    _drawGyriCurve(canvas, foldPaint, center, rx, ry, 0.25, -0.85, 0.40, -0.68, 0.20, -0.52);
    _drawGyriCurve(canvas, foldPaint, center, rx, ry, 0.55, -0.80, 0.70, -0.60, 0.50, -0.45);
    _drawGyriCurve(canvas, foldPaint, center, rx, ry, 0.75, -0.48, 0.55, -0.38, 0.65, -0.20);

    // Left side C curves
    _drawGyriCurve(canvas, foldPaint, center, rx, ry, -0.85, 0.10, -0.65, 0.18, -0.78, 0.40);
    _drawGyriCurve(canvas, foldPaint, center, rx, ry, -0.70, 0.50, -0.50, 0.58, -0.60, 0.75);

    // Right side C curves
    _drawGyriCurve(canvas, foldPaint, center, rx, ry, 0.85, 0.10, 0.65, 0.18, 0.78, 0.40);
    _drawGyriCurve(canvas, foldPaint, center, rx, ry, 0.70, 0.50, 0.50, 0.58, 0.60, 0.75);

    // Bottom chin creases
    _drawGyriCurve(canvas, foldPaint, center, rx, ry, -0.35, 0.75, -0.20, 0.62, -0.08, 0.72);
    _drawGyriCurve(canvas, foldPaint, center, rx, ry, 0.35, 0.75, 0.20, 0.62, 0.08, 0.72);

    // Mini branching twigs
    final twigPaint = Paint()
      ..color = foldColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, foldWidth * 0.75)
      ..strokeCap = StrokeCap.round;
    _drawGyriCurve(canvas, twigPaint, center, rx, ry, -0.48, -0.35, -0.42, -0.22, -0.52, -0.15);
    _drawGyriCurve(canvas, twigPaint, center, rx, ry, 0.48, -0.35, 0.42, -0.22, 0.52, -0.15);

    // Tiers 3 & 4: Realistic Walnut Fissure Lines
    if (tier.level >= 2) {
      final extraPaint = Paint()
        ..color = foldColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round;

      _drawWalnutCreaseLine(canvas, extraPaint, center, rx, ry, -0.40, -0.60, -0.20, -0.35);
      _drawWalnutCreaseLine(canvas, extraPaint, center, rx, ry, 0.20, -0.35, 0.40, -0.60);
      _drawWalnutCreaseLine(canvas, extraPaint, center, rx, ry, -0.70, 0.20, -0.45, 0.35);
      _drawWalnutCreaseLine(canvas, extraPaint, center, rx, ry, 0.45, 0.35, 0.70, 0.20);
    }

    if (tier.level == 3) {
      final walnutGroove = Paint()
        ..color = foldColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.1
        ..strokeCap = StrokeCap.round;

      _drawZigzagWalnutGroove(canvas, walnutGroove, center, rx, ry, -0.60, -0.35, -0.15, -0.28);
      _drawZigzagWalnutGroove(canvas, walnutGroove, center, rx, ry, 0.15, -0.28, 0.60, -0.35);
      _drawZigzagWalnutGroove(canvas, walnutGroove, center, rx, ry, -0.80, -0.05, -0.50, 0.08);
      _drawZigzagWalnutGroove(canvas, walnutGroove, center, rx, ry, 0.50, 0.08, 0.80, -0.05);
      _drawZigzagWalnutGroove(canvas, walnutGroove, center, rx, ry, -0.45, 0.55, -0.15, 0.65);
      _drawZigzagWalnutGroove(canvas, walnutGroove, center, rx, ry, 0.15, 0.65, 0.45, 0.55);
    }
  }

  void _drawGyriCurve(Canvas canvas, Paint paint, Offset center, double rx, double ry, double x1, double y1, double cx, double cy, double x2, double y2) {
    final path = Path();
    path.moveTo(center.dx + rx * x1, center.dy + ry * y1);
    path.quadraticBezierTo(
      center.dx + rx * cx,
      center.dy + ry * cy,
      center.dx + rx * x2,
      center.dy + ry * y2,
    );
    canvas.drawPath(path, paint);
  }

  void _drawWalnutCreaseLine(Canvas canvas, Paint paint, Offset center, double rx, double ry, double x1, double y1, double x2, double y2) {
    final p1 = Offset(center.dx + rx * x1, center.dy + ry * y1);
    final p2 = Offset(center.dx + rx * x2, center.dy + ry * y2);
    final path = Path();
    path.moveTo(p1.dx, p1.dy);
    path.quadraticBezierTo((p1.dx + p2.dx) / 2 + 2, (p1.dy + p2.dy) / 2 + 2, p2.dx, p2.dy);
    canvas.drawPath(path, paint);
  }

  void _drawZigzagWalnutGroove(Canvas canvas, Paint paint, Offset center, double rx, double ry, double x1, double y1, double x2, double y2) {
    final p1 = Offset(center.dx + rx * x1, center.dy + ry * y1);
    final p2 = Offset(center.dx + rx * x2, center.dy + ry * y2);
    final path = Path();
    path.moveTo(p1.dx, p1.dy);
    final midX = (p1.dx + p2.dx) / 2;
    final midY = (p1.dy + p2.dy) / 2;
    path.lineTo(midX - 2.5, midY + 2.5);
    path.lineTo(midX + 2.5, midY - 2.5);
    path.lineTo(p2.dx, p2.dy);
    canvas.drawPath(path, paint);
  }

  // --- ARMS AND SEAMLESS CARTOON GLOVES ---
  void _drawArmsAndGloves(Canvas canvas, Offset center, double rx, double ry) {
    final Color legColor;
    final Color legOutline;
    switch (tier) {
      case FogTier.cleanMind:
        legColor = const Color(0xFFD95874);
        legOutline = const Color(0xFFB53952);
        break;
      case FogTier.mildHaze:
        legColor = const Color(0xFFCA5A70);
        legOutline = const Color(0xFFA8324A);
        break;
      case FogTier.denseFog:
        legColor = const Color(0xFFB8485E);
        legOutline = const Color(0xFF982A40);
        break;
      case FogTier.sludgeGlitch:
        legColor = const Color(0xFFA0384E);
        legOutline = const Color(0xFF882337);
        break;
    }

    final leftShoulder = Offset(center.dx - rx * 0.88, center.dy + ry * 0.20);
    final rightShoulder = Offset(center.dx + rx * 0.88, center.dy + ry * 0.20);
    const armWidth = 11.0;

    if (tier == FogTier.cleanMind) {
      // 1. FRESH: Left arm curves UP in a wave, Right arm curves OUT & DOWN with fingers down
      final waveOffset = sin(animationValue * 4 * pi) * 6.0;
      final leftHandPos = Offset(center.dx - rx * 1.25, center.dy - ry * 0.35 + waveOffset);
      final leftElbow = Offset((leftShoulder.dx + leftHandPos.dx) / 2 - 8, (leftShoulder.dy + leftHandPos.dy) / 2 + 6);

      _drawArmTube(canvas, leftShoulder, leftElbow, leftHandPos, armWidth, legColor, legOutline);
      final leftForearmAngle = atan2(leftHandPos.dy - leftElbow.dy, leftHandPos.dx - leftElbow.dx);
      _drawSeamlessCartoonGlove(canvas, leftHandPos, leftForearmAngle, isLeft: true);

      // Right arm curves gracefully OUT and DOWN
      final rightElbow = Offset(center.dx + rx * 1.22, center.dy + ry * 0.42);
      final rightHandPos = Offset(center.dx + rx * 1.15, center.dy + ry * 0.72);

      _drawArmTube(canvas, rightShoulder, rightElbow, rightHandPos, armWidth, legColor, legOutline);
      const rightAngle = pi / 2.0; // Straight DOWN!
      _drawSeamlessCartoonGlove(canvas, rightHandPos, rightAngle, isLeft: false);

    } else if (tier == FogTier.mildHaze) {
      // 2. TIRED: Both arms hanging down loosely with fingers down
      final leftHandPos = Offset(center.dx - rx * 1.02, center.dy + ry * 0.78);
      final rightHandPos = Offset(center.dx + rx * 1.02, center.dy + ry * 0.78);
      final leftElbow = Offset(leftShoulder.dx - 3, (leftShoulder.dy + leftHandPos.dy) / 2);
      final rightElbow = Offset(rightShoulder.dx + 3, (rightShoulder.dy + rightHandPos.dy) / 2);

      _drawArmTube(canvas, leftShoulder, leftElbow, leftHandPos, armWidth, legColor, legOutline);
      _drawArmTube(canvas, rightShoulder, rightElbow, rightHandPos, armWidth, legColor, legOutline);

      final leftAngle = atan2(leftHandPos.dy - leftElbow.dy, leftHandPos.dx - leftElbow.dx);
      final rightAngle = atan2(rightHandPos.dy - rightElbow.dy, rightHandPos.dx - rightElbow.dx);
      _drawSeamlessCartoonGlove(canvas, leftHandPos, leftAngle, isLeft: true);
      _drawSeamlessCartoonGlove(canvas, rightHandPos, rightAngle, isLeft: false);

    } else if (tier == FogTier.denseFog) {
      // 3. HEAVY: Wide, curvy flared elbows gripping temples
      final leftHandPos = Offset(center.dx - rx * 0.88, center.dy - ry * 0.12);
      final rightHandPos = Offset(center.dx + rx * 0.88, center.dy - ry * 0.12);
      final leftElbow = Offset(center.dx - rx * 1.42, center.dy + ry * 0.26);
      final rightElbow = Offset(center.dx + rx * 1.42, center.dy + ry * 0.26);

      _drawArmTube(canvas, leftShoulder, leftElbow, leftHandPos, armWidth, legColor, legOutline);
      _drawArmTube(canvas, rightShoulder, rightElbow, rightHandPos, armWidth, legColor, legOutline);

      final leftAngle = atan2(leftHandPos.dy - leftElbow.dy, leftHandPos.dx - leftElbow.dx);
      final rightAngle = atan2(rightHandPos.dy - rightElbow.dy, rightHandPos.dx - rightElbow.dx);
      _drawSeamlessCartoonGlove(canvas, leftHandPos, leftAngle, isLeft: true);
      _drawSeamlessCartoonGlove(canvas, rightHandPos, rightAngle, isLeft: false);

    } else {
      // 4. OVERLOADED: Hands trembling near face in sobbing posture
      final tremble = sin(animationValue * 30 * pi) * 1.5;
      final leftHandPos = Offset(center.dx - rx * 0.45 + tremble, center.dy + ry * 0.40);
      final rightHandPos = Offset(center.dx + rx * 0.45 - tremble, center.dy + ry * 0.40);
      final leftElbow = Offset(center.dx - rx * 0.85, center.dy + ry * 0.50);
      final rightElbow = Offset(center.dx + rx * 0.85, center.dy + ry * 0.50);

      _drawArmTube(canvas, leftShoulder, leftElbow, leftHandPos, armWidth, legColor, legOutline);
      _drawArmTube(canvas, rightShoulder, rightElbow, rightHandPos, armWidth, legColor, legOutline);

      final leftAngle = atan2(leftHandPos.dy - leftElbow.dy, leftHandPos.dx - leftElbow.dx);
      final rightAngle = atan2(rightHandPos.dy - rightElbow.dy, rightHandPos.dx - rightElbow.dx);
      _drawSeamlessCartoonGlove(canvas, leftHandPos, leftAngle, isLeft: true);
      _drawSeamlessCartoonGlove(canvas, rightHandPos, rightAngle, isLeft: false);
    }
  }

  void _drawArmTube(Canvas canvas, Offset p1, Offset ctrl, Offset p2, double width, Color legColor, Color legOutline) {
    final path = Path();
    path.moveTo(p1.dx, p1.dy);
    path.quadraticBezierTo(ctrl.dx, ctrl.dy, p2.dx, p2.dy);

    final outlinePaint = Paint()
      ..color = legOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = width + 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, outlinePaint);

    final fillPaint = Paint()
      ..color = legColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, fillPaint);
  }

  void _drawSeamlessCartoonGlove(Canvas canvas, Offset pos, double forearmAngle, {required bool isLeft}) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(forearmAngle);

    final mirrorY = isLeft ? 1.0 : -1.0;
    canvas.scale(1.0, mirrorY);

    final fillPaint = Paint()..color = Colors.white;
    final strokePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. Wrist Cuff
    final cuffRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-4, -9, 7, 18),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(cuffRect, fillPaint);
    canvas.drawRRect(cuffRect, strokePaint);

    // 2. Unified Hand Silhouette (Fingers extend along +X axis)
    final handPath = Path();
    handPath.moveTo(3, 7);

    // Pinky
    handPath.lineTo(15, 7.5);
    handPath.arcToPoint(const Offset(15, 3.5), radius: const Radius.circular(2.2), clockwise: false);
    handPath.lineTo(12, 3.5);

    // Middle (Longest)
    handPath.lineTo(19, 3.0);
    handPath.arcToPoint(const Offset(19, -1.6), radius: const Radius.circular(2.4), clockwise: false);
    handPath.lineTo(13, -1.6);

    // Index
    handPath.lineTo(17, -2.2);
    handPath.arcToPoint(const Offset(17, -6.5), radius: const Radius.circular(2.3), clockwise: false);
    handPath.lineTo(9, -6.5);

    // Thumb (Curved naturally inward)
    handPath.quadraticBezierTo(11, -11, 14, -14);
    handPath.arcToPoint(const Offset(10, -16), radius: const Radius.circular(2.3), clockwise: false);
    handPath.quadraticBezierTo(6, -15, 3, -7.5);
    handPath.close();

    canvas.drawPath(handPath, fillPaint);
    canvas.drawPath(handPath, strokePaint);

    // 3. Delicate finger cleft creases
    final cleftPath = Path();
    cleftPath.moveTo(12, 3.5); cleftPath.lineTo(7, 3.0);
    cleftPath.moveTo(13, -1.6); cleftPath.lineTo(8, -1.0);
    cleftPath.moveTo(9, -6.5); cleftPath.quadraticBezierTo(6, -4, 4, -2);
    canvas.drawPath(cleftPath, strokePaint);

    canvas.restore();
  }

  // --- EXPRESSIVE CARTOON FACE ---
  void _drawExpressiveFace(Canvas canvas, Offset center, double rx, double ry) {
    final eyeSpacing = rx * 0.34;
    final eyeY = center.dy + ry * 0.12;
    final leftEye = Offset(center.dx - eyeSpacing, eyeY);
    final rightEye = Offset(center.dx + eyeSpacing, eyeY);

    switch (tier) {
      case FogTier.cleanMind:
        _drawFreshFace(canvas, center, rx, ry, leftEye, rightEye);
        break;
      case FogTier.mildHaze:
        _drawTiredFace(canvas, center, rx, ry, leftEye, rightEye);
        break;
      case FogTier.denseFog:
        _drawHeavyFace(canvas, center, rx, ry, leftEye, rightEye);
        break;
      case FogTier.sludgeGlitch:
        _drawOverloadedFace(canvas, center, rx, ry, leftEye, rightEye);
        break;
    }
  }

  // --- 1. FRESH FACE (Calm spaced-out natural blink, big sparkling eyes, open smile) ---
  void _drawFreshFace(Canvas canvas, Offset center, double rx, double ry, Offset leftEye, Offset rightEye) {
    // NATURAL BLINK: Blinks only ONCE every 6 seconds, lasting ~180ms!
    // Out of 0.0 to 1.0, only between 0.94 and 0.97 does it blink
    final isBlinking = animationValue >= 0.94 && animationValue <= 0.97;

    final eyeWidth = rx * 0.24;
    final eyeHeight = ry * 0.42;

    if (isBlinking) {
      // Cute happy curved closed eyelids ^ ^
      final blinkPaint = Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      _drawHappyArc(canvas, leftEye, eyeWidth * 0.5, blinkPaint);
      _drawHappyArc(canvas, rightEye, eyeWidth * 0.5, blinkPaint);
    } else {
      // Big white cartoon scleras
      final eyeStroke = Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4;

      final eyeFill = Paint()..color = Colors.white;

      final leftRect = Rect.fromCenter(center: leftEye, width: eyeWidth, height: eyeHeight);
      final rightRect = Rect.fromCenter(center: rightEye, width: eyeWidth, height: eyeHeight);

      canvas.drawOval(leftRect, eyeFill);
      canvas.drawOval(leftRect, eyeStroke);
      canvas.drawOval(rightRect, eyeFill);
      canvas.drawOval(rightRect, eyeStroke);

      // Pupils looking forward with slight spark
      final pupilPaint = Paint()..color = const Color(0xFF1E293B);
      final pupilRadius = eyeWidth * 0.32;
      final pupilOffset = Offset(eyeWidth * 0.08, -eyeHeight * 0.04);

      canvas.drawCircle(leftEye + pupilOffset, pupilRadius, pupilPaint);
      canvas.drawCircle(rightEye + pupilOffset, pupilRadius, pupilPaint);

      // Dual white sparkles ✨
      final catchlightPaint = Paint()..color = Colors.white;
      canvas.drawCircle(leftEye + pupilOffset + Offset(-pupilRadius * 0.32, -pupilRadius * 0.32), pupilRadius * 0.40, catchlightPaint);
      canvas.drawCircle(rightEye + pupilOffset + Offset(-pupilRadius * 0.32, -pupilRadius * 0.32), pupilRadius * 0.40, catchlightPaint);

      canvas.drawCircle(leftEye + pupilOffset + Offset(pupilRadius * 0.35, pupilRadius * 0.35), pupilRadius * 0.18, catchlightPaint);
      canvas.drawCircle(rightEye + pupilOffset + Offset(pupilRadius * 0.35, pupilRadius * 0.35), pupilRadius * 0.18, catchlightPaint);
    }

    // Arched Eyebrows
    final browPaint = Paint()
      ..color = const Color(0xFF4A101D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    final leftBrow = Path();
    leftBrow.moveTo(leftEye.dx - eyeWidth * 0.5, leftEye.dy - eyeHeight * 0.65);
    leftBrow.quadraticBezierTo(leftEye.dx, leftEye.dy - eyeHeight * 0.88, leftEye.dx + eyeWidth * 0.5, leftEye.dy - eyeHeight * 0.60);
    canvas.drawPath(leftBrow, browPaint);

    final rightBrow = Path();
    rightBrow.moveTo(rightEye.dx - eyeWidth * 0.5, rightEye.dy - eyeHeight * 0.60);
    rightBrow.quadraticBezierTo(rightEye.dx, rightEye.dy - eyeHeight * 0.88, rightEye.dx + eyeWidth * 0.5, rightEye.dy - eyeHeight * 0.65);
    canvas.drawPath(rightBrow, browPaint);

    // Cute Rosy Blush
    final blushPaint = Paint()
      ..color = const Color(0xFFFF2E63).withValues(alpha: 0.32)
      ..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromCenter(center: Offset(leftEye.dx - eyeWidth * 0.3, leftEye.dy + eyeHeight * 0.55), width: 18, height: 10), blushPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(rightEye.dx + eyeWidth * 0.3, rightEye.dy + eyeHeight * 0.55), width: 18, height: 10), blushPaint);

    // Open Happy Smile with Pink Tongue
    final mouthCenter = Offset(center.dx, leftEye.dy + ry * 0.36);
    final mouthPath = Path();
    mouthPath.moveTo(mouthCenter.dx - rx * 0.22, mouthCenter.dy);
    mouthPath.quadraticBezierTo(mouthCenter.dx, mouthCenter.dy + ry * 0.35, mouthCenter.dx + rx * 0.22, mouthCenter.dy);
    mouthPath.close();

    canvas.drawPath(mouthPath, Paint()..color = const Color(0xFF2C0B12));

    canvas.save();
    canvas.clipPath(mouthPath);
    canvas.drawCircle(Offset(mouthCenter.dx, mouthCenter.dy + ry * 0.22), rx * 0.14, Paint()..color = const Color(0xFFFF6584));
    canvas.restore();

    final mouthStroke = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(mouthPath, mouthStroke);
  }

  void _drawHappyArc(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    path.moveTo(center.dx - radius, center.dy);
    path.quadraticBezierTo(center.dx, center.dy - radius * 0.8, center.dx + radius, center.dy);
    canvas.drawPath(path, paint);
  }

  // --- 2. TIRED FACE (Heavy half-closed eyelids, slow tired blink) ---
  void _drawTiredFace(Canvas canvas, Offset center, double rx, double ry, Offset leftEye, Offset rightEye) {
    final eyeWidth = rx * 0.22;
    final eyeHeight = ry * 0.38;

    final isTiredBlinking = animationValue >= 0.93 && animationValue <= 0.98;

    if (isTiredBlinking) {
      final blinkPaint = Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(leftEye.dx - eyeWidth * 0.5, leftEye.dy), Offset(leftEye.dx + eyeWidth * 0.5, leftEye.dy), blinkPaint);
      canvas.drawLine(Offset(rightEye.dx - eyeWidth * 0.5, rightEye.dy), Offset(rightEye.dx + eyeWidth * 0.5, rightEye.dy), blinkPaint);
    } else {
      final eyeStroke = Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;

      final leftRect = Rect.fromCenter(center: leftEye, width: eyeWidth, height: eyeHeight);
      final rightRect = Rect.fromCenter(center: rightEye, width: eyeWidth, height: eyeHeight);

      final pupilR = eyeWidth * 0.28;
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(leftEye.dx - eyeWidth, leftEye.dy - 1, leftEye.dx + eyeWidth, leftEye.dy + eyeHeight));
      canvas.drawOval(leftRect, Paint()..color = Colors.white);
      canvas.drawOval(leftRect, eyeStroke);
      canvas.drawCircle(leftEye + const Offset(0, 3), pupilR, Paint()..color = const Color(0xFF1E293B));
      canvas.drawCircle(leftEye + Offset(-pupilR * 0.35, 3 - pupilR * 0.35), pupilR * 0.38, Paint()..color = Colors.white);
      canvas.restore();

      canvas.save();
      canvas.clipRect(Rect.fromLTRB(rightEye.dx - eyeWidth, rightEye.dy - 1, rightEye.dx + eyeWidth, rightEye.dy + eyeHeight));
      canvas.drawOval(rightRect, Paint()..color = Colors.white);
      canvas.drawOval(rightRect, eyeStroke);
      canvas.drawCircle(rightEye + const Offset(0, 3), pupilR, Paint()..color = const Color(0xFF1E293B));
      canvas.drawCircle(rightEye + Offset(-pupilR * 0.35, 3 - pupilR * 0.35), pupilR * 0.38, Paint()..color = Colors.white);
      canvas.restore();

      // Droopy eyelid line
      final eyelidPaint = Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(leftEye.dx - eyeWidth * 0.6, leftEye.dy - 1), Offset(leftEye.dx + eyeWidth * 0.6, leftEye.dy + 2), eyelidPaint);
      canvas.drawLine(Offset(rightEye.dx - eyeWidth * 0.6, rightEye.dy + 2), Offset(rightEye.dx + eyeWidth * 0.6, rightEye.dy - 1), eyelidPaint);

      // Under-eye tiredness creases
      final bagPaint = Paint()
        ..color = const Color(0xFFA8324A).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawArc(Rect.fromCenter(center: Offset(leftEye.dx, leftEye.dy + 5), width: eyeWidth * 0.84, height: eyeHeight * 0.4), 0.1 * pi, 0.8 * pi, false, bagPaint);
      canvas.drawArc(Rect.fromCenter(center: Offset(rightEye.dx, rightEye.dy + 5), width: eyeWidth * 0.84, height: eyeHeight * 0.4), 0.1 * pi, 0.8 * pi, false, bagPaint);
    }

    // Drooping tired brows
    final browPaint = Paint()
      ..color = const Color(0xFF4A1019)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(leftEye.dx - eyeWidth * 0.5, leftEye.dy - eyeHeight * 0.55), Offset(leftEye.dx + eyeWidth * 0.4, leftEye.dy - eyeHeight * 0.35), browPaint);
    canvas.drawLine(Offset(rightEye.dx - eyeWidth * 0.4, rightEye.dy - eyeHeight * 0.35), Offset(rightEye.dx + eyeWidth * 0.5, rightEye.dy - eyeHeight * 0.55), browPaint);

    // Wavy flat sigh mouth (~)
    final mouthCenter = Offset(center.dx, leftEye.dy + ry * 0.36);
    final mouthPath = Path();
    mouthPath.moveTo(mouthCenter.dx - rx * 0.14, mouthCenter.dy);
    mouthPath.cubicTo(
      mouthCenter.dx - rx * 0.05, mouthCenter.dy - 3,
      mouthCenter.dx + rx * 0.05, mouthCenter.dy + 3,
      mouthCenter.dx + rx * 0.14, mouthCenter.dy,
    );
    canvas.drawPath(mouthPath, Paint()..color = const Color(0xFF0F172A)..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeCap = StrokeCap.round);
  }

  // --- 3. HEAVY FACE (Squinting strained > < eyes, furrowed brows) ---
  void _drawHeavyFace(Canvas canvas, Offset center, double rx, double ry, Offset leftEye, Offset rightEye) {
    final squintPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    final sz = rx * 0.12;

    // Left >
    final leftPath = Path();
    leftPath.moveTo(leftEye.dx - sz, leftEye.dy - sz * 0.7);
    leftPath.lineTo(leftEye.dx + sz * 0.4, leftEye.dy);
    leftPath.lineTo(leftEye.dx - sz, leftEye.dy + sz * 0.7);
    canvas.drawPath(leftPath, squintPaint);

    // Right <
    final rightPath = Path();
    rightPath.moveTo(rightEye.dx + sz, rightEye.dy - sz * 0.7);
    rightPath.lineTo(rightEye.dx - sz * 0.4, rightEye.dy);
    rightPath.lineTo(rightEye.dx + sz, rightEye.dy + sz * 0.7);
    canvas.drawPath(rightPath, squintPaint);

    // Furrowed, Tense Eyebrows
    final browPaint = Paint()
      ..color = const Color(0xFF4A1019)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(leftEye.dx - sz * 1.2, leftEye.dy - sz * 1.8), Offset(leftEye.dx + sz * 0.8, leftEye.dy - sz * 1.0), browPaint);
    canvas.drawLine(Offset(rightEye.dx - sz * 0.8, rightEye.dy - sz * 1.0), Offset(rightEye.dx + sz * 1.2, rightEye.dy - sz * 1.8), browPaint);

    // Worried Panting Grimace
    final mouthCenter = Offset(center.dx, leftEye.dy + ry * 0.36);
    final mouthPath = Path();
    mouthPath.moveTo(mouthCenter.dx - rx * 0.14, mouthCenter.dy + 4);
    mouthPath.quadraticBezierTo(mouthCenter.dx, mouthCenter.dy - 6, mouthCenter.dx + rx * 0.14, mouthCenter.dy + 4);
    canvas.drawPath(mouthPath, squintPaint);
  }

  // --- 4. OVERLOADED FACE: DRY WALNUT WEEPING (╥ ﹏ ╥) ---
  void _drawOverloadedFace(Canvas canvas, Offset center, double rx, double ry, Offset leftEye, Offset rightEye) {
    final cryPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final eyeWidth = rx * 0.15;

    // Horizontal closed weeping eye bars
    canvas.drawLine(Offset(leftEye.dx - eyeWidth, leftEye.dy), Offset(leftEye.dx + eyeWidth, leftEye.dy), cryPaint);
    canvas.drawLine(Offset(rightEye.dx - eyeWidth, rightEye.dy), Offset(rightEye.dx + eyeWidth, rightEye.dy), cryPaint);

    // Tear streams pouring down from eyes (╥ ╥)
    final streamPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(leftEye.dx - eyeWidth * 0.4, leftEye.dy + 2), Offset(leftEye.dx - eyeWidth * 0.4, leftEye.dy + ry * 0.35), streamPaint);
    canvas.drawLine(Offset(leftEye.dx + eyeWidth * 0.4, leftEye.dy + 2), Offset(leftEye.dx + eyeWidth * 0.4, leftEye.dy + ry * 0.30), streamPaint);

    canvas.drawLine(Offset(rightEye.dx - eyeWidth * 0.4, rightEye.dy + 2), Offset(rightEye.dx - eyeWidth * 0.4, rightEye.dy + ry * 0.30), streamPaint);
    canvas.drawLine(Offset(rightEye.dx + eyeWidth * 0.4, rightEye.dy + 2), Offset(rightEye.dx + eyeWidth * 0.4, rightEye.dy + ry * 0.35), streamPaint);

    // Slanted weeping eyebrows
    final browPaint = Paint()
      ..color = const Color(0xFF3B0B13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(leftEye.dx - eyeWidth * 1.1, leftEye.dy - 12), Offset(leftEye.dx + eyeWidth * 0.8, leftEye.dy - 5), browPaint);
    canvas.drawLine(Offset(rightEye.dx - eyeWidth * 0.8, rightEye.dy - 5), Offset(rightEye.dx + eyeWidth * 1.1, rightEye.dy - 12), browPaint);

    // Sobbing trembling mouth (﹏)
    final mouthCenter = Offset(center.dx, leftEye.dy + ry * 0.38);
    final mouthPath = Path();
    mouthPath.moveTo(mouthCenter.dx - rx * 0.16, mouthCenter.dy);
    mouthPath.quadraticBezierTo(mouthCenter.dx - rx * 0.08, mouthCenter.dy - 6, mouthCenter.dx, mouthCenter.dy);
    mouthPath.quadraticBezierTo(mouthCenter.dx + rx * 0.08, mouthCenter.dy - 6, mouthCenter.dx + rx * 0.16, mouthCenter.dy);
    canvas.drawPath(mouthPath, cryPaint);
  }

  // --- STATUS PARTICLES (SPARKLES, SWEAT, FALLING TEARDROPS) ---
  void _drawStatusParticles(Canvas canvas, Offset center, double rx, double ry, double totalHeight) {
    if (tier == FogTier.cleanMind) {
      _drawSparkle(canvas, Offset(center.dx + rx * 0.88, center.dy - ry * 0.85), 6.5, animationValue);
      _drawSparkle(canvas, Offset(center.dx - rx * 0.85, center.dy - ry * 0.75), 5.5, animationValue + 0.45);
    } else if (tier == FogTier.mildHaze) {
      // Stage 2: Calm tired face, no tear
    } else if (tier == FogTier.denseFog) {
      // Stage 3: SINGLE slow side teardrop on right cheek (speed: 0.45)
      final eyeSpacing = rx * 0.34;
      final eyeY = center.dy + ry * 0.12;
      final phase = (animationValue * 0.45) % 1.0;

      _drawDroppingTear(
        canvas,
        startX: center.dx + eyeSpacing * 0.95 + 4,
        startY: eyeY + 4,
        totalDistance: ry * 0.55,
        phase: phase,
        maxRadius: 4.8,
      );
    } else if (tier == FogTier.sludgeGlitch) {
      // Stage 4: Overloaded weeping tears pouring down past chin
      final eyeSpacing = rx * 0.34;
      final eyeY = center.dy + ry * 0.12;

      for (int i = 0; i < 4; i++) {
        final double phase = (animationValue * 2.8 + i * 0.25) % 1.0;
        final bool isLeft = i % 2 == 0;
        final double startX = center.dx + (isLeft ? -eyeSpacing : eyeSpacing) + (i >= 2 ? (isLeft ? -5.0 : 5.0) : 0.0);
        _drawDroppingTear(
          canvas,
          startX: startX,
          startY: eyeY + ry * 0.25,
          totalDistance: totalHeight * 0.45,
          phase: phase,
          maxRadius: 4.8,
        );
      }
    }
  }

  // Smooth realistic falling tear: fades in at the eye, travels down, fades completely to 0 at the bottom,
  // stays vanished during a pause, and then freshly emerges from the eye again (NEVER jumps back up).
  void _drawDroppingTear(
    Canvas canvas, {
    required double startX,
    required double startY,
    required double totalDistance,
    required double phase,
    required double maxRadius,
  }) {
    // Only visible during 0.0 to 0.72 of its cycle; remaining 28% of cycle is an empty pause
    if (phase > 0.72) return;

    final double p = phase / 0.72; // Normalized lifetime 0.0 to 1.0
    final double tearY = startY + p * totalDistance;

    // Fade-in when emerging from eye (0.0 to 0.15), solid on cheek (0.15 to 0.50), complete fade-out to 0 (0.50 to 1.0)
    final double alpha;
    if (p < 0.15) {
      alpha = p / 0.15;
    } else if (p < 0.50) {
      alpha = 1.0;
    } else {
      alpha = ((1.0 - p) / 0.50).clamp(0.0, 1.0);
    }

    if (alpha <= 0.01) return;

    final double radius = maxRadius * (0.65 + 0.35 * p);
    _drawTeardrop(canvas, Offset(startX, tearY), radius, alpha);
  }

  void _drawSparkle(Canvas canvas, Offset pos, double size, double phase) {
    final pulse = (sin(phase * 2 * pi) * 0.5 + 0.5);
    final paint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.7 * pulse)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(pos.dx, pos.dy - size * pulse);
    path.quadraticBezierTo(pos.dx, pos.dy, pos.dx + size * pulse, pos.dy);
    path.quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy + size * pulse);
    path.quadraticBezierTo(pos.dx, pos.dy, pos.dx - size * pulse, pos.dy);
    path.quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy - size * pulse);

    canvas.drawPath(path, paint);
  }

  void _drawTeardrop(Canvas canvas, Offset pos, double radius, double alpha) {
    final dropPaint = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: alpha * 0.85)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(pos.dx, pos.dy - radius * 1.8);
    path.cubicTo(
      pos.dx + radius * 1.1, pos.dy - radius * 0.4,
      pos.dx + radius * 1.1, pos.dy + radius,
      pos.dx, pos.dy + radius,
    );
    path.cubicTo(
      pos.dx - radius * 1.1, pos.dy + radius,
      pos.dx - radius * 1.1, pos.dy - radius * 0.4,
      pos.dx, pos.dy - radius * 1.8,
    );
    path.close();

    canvas.drawPath(path, dropPaint);
    canvas.drawCircle(Offset(pos.dx - radius * 0.3, pos.dy + radius * 0.2), radius * 0.3, Paint()..color = Colors.white.withValues(alpha: alpha * 0.75));
  }

  @override
  bool shouldRepaint(covariant BrainFogPainter oldDelegate) {
    return oldDelegate.fogPercentage != fogPercentage ||
        oldDelegate.tier != tier ||
        oldDelegate.animationValue != animationValue;
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PermissionGuideMockup extends StatefulWidget {
  final String screenTitle;
  final bool isUsageAccess;

  const PermissionGuideMockup({
    super.key,
    required this.screenTitle,
    this.isUsageAccess = true,
  });

  @override
  State<PermissionGuideMockup> createState() => _PermissionGuideMockupState();
}

class _PermissionGuideMockupState extends State<PermissionGuideMockup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final innerBg = isDark ? const Color(0xFF0B0F17) : const Color(0xFFF1F5F9);
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;

        // Pointer animation timing:
        // 0.00 - 0.20: Glide in
        // 0.20 - 0.35: Tap / scale down
        // 0.35 - 0.82: Switch ON, pointer stays briefly then fades
        // 0.82 - 1.00: Fade out / reset
        double pointerOpacity = 0.0;
        double pointerScale = 1.0;
        double pointerXOffset = 0.0;
        double pointerYOffset = 0.0;

        if (progress < 0.20) {
          final t = progress / 0.20;
          pointerOpacity = Curves.easeOut.transform(t);
          pointerXOffset = (1.0 - t) * 14.0;
          pointerYOffset = (1.0 - t) * 14.0;
        } else if (progress < 0.35) {
          pointerOpacity = 1.0;
          final t = (progress - 0.20) / 0.15;
          // Scale dip for tap feel: 1.0 -> 0.82 -> 1.0
          pointerScale = 1.0 - math.sin(t * math.pi) * 0.18;
        } else if (progress < 0.80) {
          pointerOpacity = 0.95;
          pointerScale = 1.0;
        } else if (progress < 0.95) {
          final t = (progress - 0.80) / 0.15;
          pointerOpacity = (1.0 - t).clamp(0.0, 1.0);
          pointerScale = 1.0 - t * 0.15;
        } else {
          pointerOpacity = 0.0;
        }

        // Switch toggle timing (flips ON at progress 0.35)
        double switchProgress = 0.0;
        if (progress >= 0.35 && progress < 0.88) {
          final t = ((progress - 0.35) / 0.12).clamp(0.0, 1.0);
          switchProgress = Curves.easeInOutCubic.transform(t);
        } else if (progress >= 0.88) {
          final t = ((progress - 0.88) / 0.12).clamp(0.0, 1.0);
          switchProgress = (1.0 - t).clamp(0.0, 1.0);
        }

        final switchColor = Color.lerp(
          isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
          AppTheme.mint,
          switchProgress,
        )!;

        final isTargetHighlighted = switchProgress > 0.05;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: innerBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mini top bar
                  Row(
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 14, color: textMuted),
                      const SizedBox(width: 8),
                      Text(
                        widget.screenTitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: textMuted,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Divider(height: 1, color: borderColor.withValues(alpha: 0.5)),
                  const SizedBox(height: 4),

                  // App 1: Chrome (Clear realistic app item)
                  _buildMockRow(
                    icon: Icons.language,
                    iconBg: const Color(0xFF2563EB),
                    iconColor: Colors.white,
                    appName: 'Chrome',
                    status: 'Not allowed',
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                  ),
                  const SizedBox(height: 3),

                  // App 2: DefogMind (Target app row!)
                  Container(
                    decoration: BoxDecoration(
                      color: isTargetHighlighted
                          ? AppTheme.mint.withValues(alpha: isDark ? 0.14 : 0.10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: isTargetHighlighted
                            ? AppTheme.mint.withValues(alpha: 0.45)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                    child: Row(
                      children: [
                        // App Logo Icon
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            color: isDark ? const Color(0xFF161E2E) : Colors.white,
                            border: Border.all(
                              color: AppTheme.mint.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(2.5),
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.psychology,
                              size: 16,
                              color: AppTheme.mint,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'DefogMind',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                switchProgress > 0.5 ? 'Allowed' : 'Tap to allow',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: switchProgress > 0.5
                                      ? AppTheme.mint
                                      : textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Animated Toggle Switch
                        Container(
                          width: 34,
                          height: 19,
                          decoration: BoxDecoration(
                            color: switchColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(2),
                          alignment: Alignment.centerLeft,
                          child: Transform.translate(
                            offset: Offset(switchProgress * 15.0, 0),
                            child: Container(
                              width: 15,
                              height: 15,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: switchProgress > 0.7
                                  ? const Icon(
                                      Icons.check,
                                      size: 10,
                                      color: AppTheme.mint,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),

                  // App 3: Messages (Clear realistic app item)
                  _buildMockRow(
                    icon: Icons.chat_bubble_outline_rounded,
                    iconBg: const Color(0xFF0D9488),
                    iconColor: Colors.white,
                    appName: 'Messages',
                    status: 'Not allowed',
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                  ),
                  const SizedBox(height: 3),

                  // App 4: YouTube (4th app to make it look like a complete Android list)
                  _buildMockRow(
                    icon: Icons.play_arrow_rounded,
                    iconBg: const Color(0xFFDC2626),
                    iconColor: Colors.white,
                    appName: widget.isUsageAccess ? 'YouTube' : 'Camera',
                    status: 'Not allowed',
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                  ),
                ],
              ),

              // Animated Touch Pointer (Finger Indicator positioned over DefogMind switch)
              if (pointerOpacity > 0.01)
                Positioned(
                  right: 4 + pointerXOffset,
                  top: 60 + pointerYOffset,
                  child: Opacity(
                    opacity: pointerOpacity,
                    child: Transform.scale(
                      scale: pointerScale,
                      child: Container(
                        padding: const EdgeInsets.all(5.5),
                        decoration: BoxDecoration(
                          color: AppTheme.mint.withValues(alpha: 0.28),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.mint, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.mint.withValues(alpha: 0.35),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.touch_app_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMockRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String appName,
    required String status,
    required Color textPrimary,
    required Color textMuted,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              appName,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ),
          Text(
            status,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

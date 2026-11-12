import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class FloatingCountdownPillWidget extends StatelessWidget {
  final int remainingSeconds;
  final bool isPaused;
  final VoidCallback? onTap;

  const FloatingCountdownPillWidget({
    super.key,
    required this.remainingSeconds,
    this.isPaused = false,
    this.onTap,
  });

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard(context).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isPaused ? AppTheme.warningAmber : AppTheme.mint,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isPaused ? AppTheme.warningAmber : AppTheme.mint).withValues(alpha: 0.25),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPaused ? Icons.pause_circle_outline : Icons.air,
              color: isPaused ? AppTheme.warningAmber : AppTheme.mint,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              isPaused
                  ? 'Oxygen Pass: ${_formatTime(remainingSeconds)} (Paused)'
                  : 'Oxygen Pass: ${_formatTime(remainingSeconds)}',
              style: TextStyle(
                color: isPaused ? AppTheme.warningAmber : AppTheme.mint,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


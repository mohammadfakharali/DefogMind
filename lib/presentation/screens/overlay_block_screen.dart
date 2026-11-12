import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../services/oxygen_pass_manager.dart';
import '../../services/admob_service.dart';

class OverlayBlockScreen extends StatefulWidget {
  final String blockedAppName;

  const OverlayBlockScreen({
    super.key,
    this.blockedAppName = 'Social App',
  });

  @override
  State<OverlayBlockScreen> createState() => _OverlayBlockScreenState();
}

class _OverlayBlockScreenState extends State<OverlayBlockScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  int _secondsRemaining = 10;
  Timer? _timer;
  bool _isFrictionGateOpen = false;
  int _remainingPasses = 2;
  int _passDurationMinutes = 5;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _loadPassCount();

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          _secondsRemaining = 0;
          _isFrictionGateOpen = true;
        });
      }
    });
  }

  Future<void> _loadPassCount() async {
    final passes = await OxygenPassManager.getRemainingPasses();
    final durationSeconds = await OxygenPassManager.getPassDuration();
    if (mounted) {
      setState(() {
        _remainingPasses = passes;
        _passDurationMinutes = durationSeconds ~/ 60;
      });
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _claimEmergencyBypass() async {
    if (!_isFrictionGateOpen || _isClaiming) return;
    setState(() => _isClaiming = true);

    if (_remainingPasses > 0) {
      final success = await OxygenPassManager.usePass();
      if (success && mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      _promptRewardedAdUnlock();
    }
    setState(() => _isClaiming = false);
  }

  void _promptRewardedAdUnlock() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.cardBorder(context)),
        ),
        title: Text(
          'Daily Passes Finished',
          style: TextStyle(color: AppTheme.textPrimary(context), fontWeight: FontWeight.w700),
        ),
        content: Text(
          'You have used your 2 free daily Extra Unlock Passes. Would you like to get 1 extra pass by watching a short video?',
          style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mint,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _showRewardedAd();
            },
            child: const Text('Watch Video (+1 Pass)', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showRewardedAd() {
    AdMobService.instance.showRewardedAd(
      onRewardEarned: () async {
        await OxygenPassManager.addBonusPassFromAd();
        await _loadPassCount();
        await _claimEmergencyBypass();
      },
      onAdUnavailable: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video ad is loading. Please try again in a few seconds.'),
            backgroundColor: AppTheme.warningAmber,
          ),
        );
      },
    );
  }

  void _exitToHome() {
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _exitToHome();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background(context),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Tag
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.glitchCoral.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.glitchCoral.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'DAILY LIMIT REACHED',
                        style: TextStyle(
                          color: AppTheme.glitchCoral,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${widget.blockedAppName} is Blocked',
                      style: TextStyle(
                        color: AppTheme.textPrimary(context),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You have reached your daily screen time limit. Take a short pause and breathe.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13.5, height: 1.4),
                    ),
                  ],
                ),

                // Center Breathing Circle
                Column(
                  children: [
                    AnimatedBuilder(
                      animation: _breathingController,
                      builder: (context, child) {
                        final scale = 1.0 + (_breathingController.value * 0.25);
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppTheme.mint.withValues(alpha: 0.22),
                                  AppTheme.cyan.withValues(alpha: 0.06),
                                  Colors.transparent,
                                ],
                              ),
                              border: Border.all(
                                color: _isFrictionGateOpen ? AppTheme.mint : AppTheme.cyan,
                                width: 2.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _isFrictionGateOpen ? '✓' : '${_secondsRemaining}s',
                                style: TextStyle(
                                  color: _isFrictionGateOpen ? AppTheme.mint : AppTheme.textPrimary(context),
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _isFrictionGateOpen
                          ? 'Breathing finished! You can now unlock.'
                          : (_secondsRemaining > 6
                              ? 'Breathe in slowly...'
                              : (_secondsRemaining > 3 ? 'Hold gently...' : 'Exhale slowly...')),
                      style: TextStyle(
                        color: _isFrictionGateOpen ? AppTheme.mint : AppTheme.cyan,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isFrictionGateOpen
                          ? '$_remainingPasses extra unlock ${_remainingPasses == 1 ? "pass" : "passes"} remaining today'
                          : 'Sit with the breath for 10 seconds before unlocking',
                      style: TextStyle(color: AppTheme.textMuted(context), fontSize: 12),
                    ),
                  ],
                ),

                // Action Buttons
                Column(
                  children: [
                    // Top 3-line Extra Unlock button
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFrictionGateOpen ? AppTheme.mint : AppTheme.surfaceCard(context),
                          foregroundColor: _isFrictionGateOpen ? Colors.black : AppTheme.textMuted(context),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        onPressed: _isFrictionGateOpen ? _claimEmergencyBypass : null,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Claim $_passDurationMinutes Minutes',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '(Extra unlock)',
                              style: TextStyle(
                                fontSize: 11,
                                color: _isFrictionGateOpen ? Colors.black87 : AppTheme.textMuted(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Bottom 2-line Leave The App button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.cyan,
                          side: BorderSide(color: AppTheme.cardBorder(context)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        ),
                        onPressed: _exitToHome,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Leave The App', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            Text('(Go To Home)', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'DefogMind is a digital habit and productivity utility. It does not provide medical advice, diagnosis, or treatment for cognitive conditions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted(context), fontSize: 10, height: 1.3),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

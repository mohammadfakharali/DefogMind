import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/social_apps.dart';
import '../../core/theme/app_theme.dart';
import '../../services/fog_calculator.dart';
import '../../services/usage_service.dart';
import '../../services/oxygen_pass_manager.dart';
import '../../services/admob_service.dart';
import '../../presentation/widgets/brain_fog_painter.dart';
import '../../presentation/widgets/banner_ad_widget.dart';
import '../../presentation/widgets/math_challenge_dialog.dart';
import '../../presentation/widgets/parent_pin_dialog.dart';
import 'app_selection_screen.dart';
import 'kids_mode_setup_screen.dart';
import 'settings_screen.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> with WidgetsBindingObserver {
  int _focusMode = 1; // 0: Awareness, 1: Limit Mode
  bool _isAdultTrackingEnabled = true;
  List<String> _monitoredPackages = [];
  Map<String, int> _appUsageMillis = {};
  Map<String, int> _kidsUsageMillis = {};
  int _totalSocialMinutes = 0; // Adult social minutes (excludes Kids Mode usage)
  int _totalKidsMinutes = 0;   // Kids Mode usage minutes today
  int _dailyLimitMinutes = 60;
  int _remainingPasses = 2;
  int _passiveRecoveryMinutes = 0;
  int? _cachedServiceFog;
  bool _isAllAppsExpanded = false;
  bool _isNavigatingToApps = false;
  bool _isKidsModeActive = false;
  int _kidsLimitMinutes = 30;
  int _kidsRemainingSeconds = 1800;
  List<String> _kidsAllowedPackages = ['com.google.android.youtube'];
  Map<String, String> _installedAppNames = {};
  Timer? _refreshTimer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchUsageData());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchUsageData();
    }
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getInt('focus_mode') ?? 1;
    final adultEnabled = prefs.getBool('adult_tracking_enabled') ?? true;
    final packages = prefs.getStringList('monitored_packages') ?? SocialApps.defaultPackageList;
    final limit = prefs.getInt('daily_limit_minutes') ?? 60;
    final passes = await OxygenPassManager.getRemainingPasses();
    final lastExitMs = prefs.getInt('last_social_exit_ms') ?? 0;
    final brainStatus = await UsageService.getBrainFogStatus();
    final liveFog = (brainStatus['percentage'] as num?)?.toInt() ?? 0;
    int recoveryMins = 0;
    if (lastExitMs > 0) {
      final diffMs = DateTime.now().millisecondsSinceEpoch - lastExitMs;
      if (diffMs > 0) {
        recoveryMins = (diffMs / 60000).clamp(0, 480).toInt();
      }
    }

    setState(() {
      _focusMode = mode;
      _isAdultTrackingEnabled = adultEnabled;
      _monitoredPackages = packages;
      _dailyLimitMinutes = limit;
      _remainingPasses = passes;
      _passiveRecoveryMinutes = recoveryMins;
      _cachedServiceFog = liveFog;
    });

    final duration = prefs.getInt('oxygen_pass_duration_seconds') ?? 300;
    UsageService.startFocusService(
      mode: mode,
      adultTrackingEnabled: adultEnabled,
      passDuration: duration,
      dailyLimit: limit,
      packages: packages,
    );

    await _fetchUsageData();
    if (mounted) setState(() => _isLoading = false);

    // Lazily preload installed apps & AdMob after the dashboard UI is already rendered and responsive
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      UsageService.getInstalledApps().then((apps) {
        if (mounted) {
          final Map<String, String> nameMap = {};
          for (final app in apps) {
            final pkg = app['packageName'] ?? '';
            final name = app['appName'] ?? pkg;
            if (pkg.isNotEmpty) nameMap[pkg] = name;
          }
          setState(() => _installedAppNames = nameMap);
        }
      });
    });

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && !_isKidsModeActive) {
        AdMobService.instance.initialize().catchError((_) {});
      }
    });
  }

  Future<void> _fetchUsageData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKidsAllowed = prefs.getStringList('kids_allowed_packages') ?? ['com.google.android.youtube'];
    final savedKidsLimit = prefs.getInt('kids_limit_minutes') ?? 30;
    final kidsStatus = await UsageService.getKidsModeStatus();

    final bool isKidsActive = (kidsStatus['isActive'] as bool?) ?? false;
    final int kidsRemainingSecs = (kidsStatus['remainingSeconds'] as num?)?.toInt() ?? (savedKidsLimit * 60);
    final Map<String, int> kidsUsageMap = Map<String, int>.from(
      (kidsStatus['kidsUsageMillis'] as Map?) ?? <String, int>{},
    );

    // Query usage across both Adult monitored packages and any packages used in Kids Mode today
    final Set<String> allTrackedPkgs = {..._monitoredPackages, ...kidsUsageMap.keys};
    final stats = await UsageService.getDailyUsageStats(allTrackedPkgs.toList());

    final Map<String, int> fullMap = {};
    for (final pkg in _monitoredPackages) {
      fullMap[pkg] = stats[pkg] ?? 0;
    }
    for (final pkg in kidsUsageMap.keys) {
      if (!fullMap.containsKey(pkg)) {
        fullMap[pkg] = stats[pkg] ?? kidsUsageMap[pkg] ?? 0;
      }
    }

    int adultTotalMs = 0;
    for (final pkg in _monitoredPackages) {
      final rawMs = fullMap[pkg] ?? 0;
      final kidsMs = kidsUsageMap[pkg] ?? 0;
      final adultOnlyMs = (rawMs - kidsMs).clamp(0, rawMs);
      adultTotalMs += adultOnlyMs;
    }

    int kidsTotalMs = 0;
    kidsUsageMap.forEach((_, ms) => kidsTotalMs += ms);

    final passes = await OxygenPassManager.getRemainingPasses();
    final lastExitMs = prefs.getInt('last_social_exit_ms') ?? 0;
    final brainStatus = await UsageService.getBrainFogStatus();
    final liveFog = (brainStatus['percentage'] as num?)?.toInt() ?? 0;
    int recoveryMins = 0;
    if (lastExitMs > 0) {
      final diffMs = DateTime.now().millisecondsSinceEpoch - lastExitMs;
      if (diffMs > 0) {
        recoveryMins = (diffMs / 60000).clamp(0, 480).toInt();
      }
    }

    if (mounted) {
      final adultEnabled = prefs.getBool('adult_tracking_enabled') ?? true;
      setState(() {
        _isAdultTrackingEnabled = adultEnabled;
        _appUsageMillis = fullMap;
        _kidsUsageMillis = kidsUsageMap;
        _totalSocialMinutes = (adultTotalMs / (1000 * 60)).round();
        _totalKidsMinutes = (kidsTotalMs / (1000 * 60)).round();
        _remainingPasses = passes;
        _passiveRecoveryMinutes = recoveryMins;
        _cachedServiceFog = liveFog;
        _isKidsModeActive = isKidsActive;
        _kidsLimitMinutes = savedKidsLimit;
        _kidsRemainingSeconds = kidsRemainingSecs;
        _kidsAllowedPackages = savedKidsAllowed;
      });
    }
  }

  void _startKidsMode() {
    ParentPinDialog.ensurePinAndRun(
      context: context,
      actionDescription: 'lock Kids Mode',
      requireVerificationIfAlreadySet: false,
      onSuccess: () async {
        final prefs = await SharedPreferences.getInstance();
        final allowed = prefs.getStringList('kids_allowed_packages') ?? _kidsAllowedPackages;
        final limitMins = prefs.getInt('kids_limit_minutes') ?? _kidsLimitMinutes;
        final totalSecs = limitMins * 60;

        await UsageService.setKidsMode(
          active: true,
          limitMinutes: limitMins,
          remainingSeconds: totalSecs,
          allowedPackages: allowed,
        );

        if (mounted) {
          setState(() {
            _isKidsModeActive = true;
            _kidsLimitMinutes = limitMins;
            _kidsRemainingSeconds = totalSecs;
            _kidsAllowedPackages = allowed;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🧸 Kids Mode Active! Adult stats & Brain Fog are protected.'),
              backgroundColor: AppTheme.cyan,
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  void _unlockAndEndKidsMode() {
    ParentPinDialog.ensurePinAndRun(
      context: context,
      actionDescription: 'turn off Kids Mode',
      requireVerificationIfAlreadySet: true,
      onSuccess: () async {
        await UsageService.setKidsMode(
          active: false,
          limitMinutes: _kidsLimitMinutes,
          remainingSeconds: _kidsRemainingSeconds,
          allowedPackages: _kidsAllowedPackages,
        );

        await _fetchUsageData();
        if (mounted) {
          setState(() => _isKidsModeActive = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kids Mode turned OFF. Welcome back!'),
              backgroundColor: AppTheme.mint,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // 100% policy-safe interstitial ad trigger: ONLY after Parent PIN verification when exiting Kids Mode!
        AdMobService.instance.showInterstitialIfAllowed();
      },
    );
  }

  void _changeFocusMode(int targetMode) {
    if (targetMode == _focusMode) return;

    final targetName = targetMode == 0 ? 'Awareness Mode' : 'Limit Mode';
    MathChallengeDialog.show(
      context: context,
      actionDescription: 'switch to $targetName',
      onSolved: () => _applyFocusMode(targetMode),
    );
  }

  Future<void> _applyFocusMode(int mode) async {
    setState(() => _focusMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('focus_mode', mode);

    final duration = prefs.getInt('oxygen_pass_duration_seconds') ?? 300;
    await UsageService.updateServiceConfig(
      mode: mode,
      adultTrackingEnabled: _isAdultTrackingEnabled,
      passDuration: duration,
      dailyLimit: _dailyLimitMinutes,
      packages: _monitoredPackages,
    );

    if (mounted) {
      final name = mode == 0 ? 'Awareness Mode' : 'Limit Mode';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to $name'),
          backgroundColor: AppTheme.mint,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _resumeAdultTracking() async {
    setState(() => _isAdultTrackingEnabled = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('adult_tracking_enabled', true);

    final duration = prefs.getInt('oxygen_pass_duration_seconds') ?? 300;
    await UsageService.updateServiceConfig(
      mode: _focusMode,
      adultTrackingEnabled: true,
      passDuration: duration,
      dailyLimit: _dailyLimitMinutes,
      packages: _monitoredPackages,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('My App Tracking resumed!'),
          backgroundColor: AppTheme.mint,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _watchAdForPass() {
    AdMobService.instance.showRewardedAd(
      onRewardEarned: () async {
        await OxygenPassManager.addBonusPassFromAd();
        final passes = await OxygenPassManager.getRemainingPasses();
        if (mounted) {
          setState(() => _remainingPasses = passes);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('+1 Extra Unlock Pass earned!'),
              backgroundColor: AppTheme.mint,
            ),
          );
        }
      },
      onAdUnavailable: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video ad is loading. Please try again shortly.'),
            backgroundColor: AppTheme.warningAmber,
          ),
        );
      },
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (mounted) _loadState();
  }

  @override
  Widget build(BuildContext context) {
    final fogResult = FogCalculator.calculate(
      focusMode: _focusMode,
      totalSocialMinutes: _totalSocialMinutes,
      passiveRecoveryMinutes: _passiveRecoveryMinutes,
      dailyLimitMinutes: _dailyLimitMinutes,
      cachedServiceFog: _cachedServiceFog,
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_isKidsModeActive ? '🧸 DefogMind Kids Mode' : 'DefogMind'),
        actions: [
          if (!_isKidsModeActive)
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: AppTheme.textPrimary),
              tooltip: 'Settings',
              onPressed: _openSettings,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.mint))
          : _isKidsModeActive
              ? _buildKidsModeActiveScreen()
              : RefreshIndicator(
                  color: AppTheme.mint,
                  backgroundColor: AppTheme.surfaceCard,
                  onRefresh: _fetchUsageData,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    children: [
                      if (_isAdultTrackingEnabled) ...[
                        // Mode Switcher Selector (Adult Modes)
                        _buildModeSelector(),
                        const SizedBox(height: 20),

                        // Brain Fog Visualizer Card (No text overflows)
                        _buildBrainFogCard(fogResult),
                        const SizedBox(height: 20),

                        // Extra Unlock Pass Status Card (Shown right below Brain Fog card ONLY when Daily Limit is reached in Limit Mode)
                        if (_focusMode == 1 && _dailyLimitMinutes > 0 && _totalSocialMinutes >= _dailyLimitMinutes) ...[
                          _buildBypassTokenCard(),
                          const SizedBox(height: 20),
                        ],
                      ] else ...[
                        _buildAdultTrackingPausedCard(),
                        const SizedBox(height: 20),
                      ],

                      // 🧸 Kids Mode (Child Hand-Off) Card
                      _buildKidsModeCard(),
                      const SizedBox(height: 20),

                      // App Usage Breakdown Card (With View All + Add/Remove button)
                      _buildUsageBreakdownCard(),
                      const SizedBox(height: 20),

                      // Medical & Policy Disclaimer
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'DefogMind is a digital habit and productivity utility. It does not provide medical advice, diagnosis, or treatment for cognitive conditions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 10.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
      // Zero ads while Kids Mode is active (100% Google Play & AdMob safe)
      bottomNavigationBar: _isKidsModeActive ? null : const BannerAdWidget(),
    );
  }

  Widget _buildAdultTrackingPausedCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.warningAmber.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.warningAmber.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pause_circle_outline_rounded,
              color: AppTheme.warningAmber,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'My App Tracking Paused',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your personal Brain Fog Meter and daily limits are currently off. Kids Mode below still works anytime.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mint,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _resumeAdultTracking,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text(
                'Resume App Tracking',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          _buildModeTab(
            title: 'Awareness Mode',
            subtitle: 'No Apps Blocking',
            modeValue: 0,
            icon: Icons.visibility_outlined,
          ),
          _buildModeTab(
            title: 'Limit Mode',
            subtitle: 'Blocks Apps at Limit',
            modeValue: 1,
            icon: Icons.shield_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String title,
    required String subtitle,
    required int modeValue,
    required IconData icon,
  }) {
    final isSelected = _focusMode == modeValue;
    return Expanded(
      child: GestureDetector(
        onTap: () => _changeFocusMode(modeValue),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.mint.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppTheme.mint : Colors.transparent,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? AppTheme.mint : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isSelected ? AppTheme.mint : AppTheme.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrainFogCard(FogCalculationResult result) {
    final Color badgeColor;
    switch (result.tier) {
      case FogTier.cleanMind:
        badgeColor = AppTheme.mint;
        break;
      case FogTier.mildHaze:
        badgeColor = AppTheme.warningAmber;
        break;
      case FogTier.denseFog:
        badgeColor = const Color(0xFFFB923C); // Orange
        break;
      case FogTier.sludgeGlitch:
        badgeColor = AppTheme.glitchCoral;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          // Header: Label & Saturation Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'BRAIN FOG METER',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${result.tier.meterLabel} • ${result.fogPercentage.toStringAsFixed(0)}% Fog',
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Vector Brain CustomPainter
          Center(
            child: BrainFogVisualizer(
              fogPercentage: result.fogPercentage,
              tier: result.tier,
              size: 220,
            ),
          ),
          const SizedBox(height: 12),

          // Status centered below brain (prevents horizontal overflow!)
          Text(
            result.tier.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: badgeColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            result.tier.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.cardBorder, height: 1),
          const SizedBox(height: 14),

          // Balanced 2-Column Stats (No right overflow)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Adult Social Time', '$_totalSocialMinutes mins', Icons.timer_outlined),
              _buildStatItem(
                'Daily Target',
                _focusMode == 1 ? '$_dailyLimitMinutes mins' : 'Awareness (No Limit)',
                Icons.track_changes_outlined,
                onTap: _openSettings,
              ),
            ],
          ),
          if (_totalKidsMinutes > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.cyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.25)),
              ),
              child: Text(
                'Adult: $_totalSocialMinutes mins  •  🧸 Kids: $_totalKidsMinutes mins  (Total: ${_totalSocialMinutes + _totalKidsMinutes}m)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.cyan,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],

          // Daily Limit Progress Bar (Shown in Limit Mode)
          if (_focusMode == 1 && _dailyLimitMinutes > 0) ...[
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final double limitRatio = (_totalSocialMinutes / _dailyLimitMinutes).clamp(0.0, 1.0);
                final int limitPercent = (limitRatio * 100).round();
                final Color limitColor = limitPercent >= 90
                    ? AppTheme.glitchCoral
                    : (limitPercent >= 60 ? AppTheme.warningAmber : AppTheme.mint);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Daily Limit Used',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$_totalSocialMinutes / $_dailyLimitMinutes mins ($limitPercent%)',
                          style: TextStyle(
                            color: limitColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: limitRatio,
                        backgroundColor: AppTheme.background,
                        valueColor: AlwaysStoppedAnimation<Color>(limitColor),
                        minHeight: 7,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {VoidCallback? onTap}) {
    final content = Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppTheme.cyan),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.edit_outlined, size: 11, color: AppTheme.cyan),
            ],
          ],
        ),
      ],
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: content,
      ),
    );
  }

  Widget _buildBypassTokenCard() {
    final bool hasPasses = _remainingPasses > 0;
    final Color badgeColor = hasPasses ? AppTheme.mint : AppTheme.warningAmber;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasPasses ? AppTheme.cardBorder : AppTheme.warningAmber.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bolt, color: badgeColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPasses
                      ? '$_remainingPasses Extra Unlock ${_remainingPasses == 1 ? "Pass" : "Passes"} Left'
                      : 'No Passes Left • Earn Pass',
                  style: TextStyle(
                    color: hasPasses ? AppTheme.textPrimary : AppTheme.warningAmber,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasPasses
                      ? 'Temporary unlock after daily limit'
                      : 'Watch a quick ad to get an Extra Unlock Pass',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: hasPasses ? AppTheme.background : AppTheme.cyan.withValues(alpha: 0.15),
              foregroundColor: AppTheme.cyan,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.cyan),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: _watchAdForPass,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.video_library_outlined, size: 15),
                const SizedBox(width: 5),
                Text(
                  hasPasses ? '+1 Pass' : 'Earn Pass',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageBreakdownCard() {
    final entries = _appUsageMillis.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Show top 5 by default, or all if expanded
    final displayedEntries = _isAllAppsExpanded ? entries : entries.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today\'s App Usage',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${entries.length} apps tracked',
                style: const TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No monitored apps selected.\nTap below to choose apps to track.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              ),
            )
          else ...[
            ...displayedEntries.map((entry) {
              final rawTotalMs = entry.value;
              final kidsMs = _kidsUsageMillis[entry.key] ?? 0;
              final adultMs = (rawTotalMs - kidsMs).clamp(0, rawTotalMs);
              final adultMinutes = (adultMs / (1000 * 60)).round();
              final kidsMinutes = (kidsMs / (1000 * 60)).round();
              final totalMinutes = (rawTotalMs / (1000 * 60)).round();
              final appName = _installedAppNames[entry.key] ?? SocialApps.getAppName(entry.key);
              final progress = _dailyLimitMinutes > 0 ? (adultMinutes / _dailyLimitMinutes).clamp(0.0, 1.0) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            appName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          kidsMinutes > 0
                              ? 'Adult: ${adultMinutes}m • 🧸 Kids: ${kidsMinutes}m'
                              : '$totalMinutes min',
                          style: TextStyle(
                            color: kidsMinutes > 0 ? AppTheme.cyan : AppTheme.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppTheme.background,
                      color: progress > 0.8 ? AppTheme.glitchCoral : AppTheme.mint,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              );
            }),

            // If more than 5 apps, provide a "View All / Show Less" button
            if (entries.length > 5) ...[
              const SizedBox(height: 4),
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _isAllAppsExpanded = !_isAllAppsExpanded),
                  icon: Icon(
                    _isAllAppsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppTheme.cyan,
                    size: 18,
                  ),
                  label: Text(
                    _isAllAppsExpanded ? 'Show Less' : 'View All (${entries.length} apps)',
                    style: const TextStyle(color: AppTheme.cyan, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: 12),
          const Divider(color: AppTheme.cardBorder, height: 1),
          const SizedBox(height: 14),

          // Prominent, clear button to Add or Remove Monitored Apps
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.mint,
                side: const BorderSide(color: AppTheme.mint, width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: _isNavigatingToApps
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.mint),
                    )
                  : const Icon(Icons.add_circle_outline, size: 18),
              label: Text(
                _isNavigatingToApps ? 'Opening app list...' : 'Add or Remove Monitored Apps',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              onPressed: _isNavigatingToApps
                  ? null
                  : () async {
                      setState(() => _isNavigatingToApps = true);
                      final updated = await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AppSelectionScreen()),
                      );
                      if (mounted) setState(() => _isNavigatingToApps = false);
                      if (updated == true && mounted) _loadState();
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKidsModeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.45), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.cyan.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Text('🧸', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kids Mode (Child Hand-Off)',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$_kidsLimitMinutes mins timer • ${_kidsAllowedPackages.length} Allowed ${_kidsAllowedPackages.length == 1 ? "App" : "Apps"}',
                      style: const TextStyle(
                        color: AppTheme.cyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Hand your phone to your child safely. Only your allowed apps work until the timer ends, and their usage will never affect your Adult Brain Fog or Daily Limit.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.cyan,
                side: const BorderSide(color: AppTheme.cyan),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                final updated = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const KidsModeSetupScreen()),
                );
                if (updated == true) _fetchUsageData();
              },
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text(
                'Setup Apps & Time',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cyan,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _startKidsMode,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text(
                'Start Kids Mode',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKidsModeActiveScreen() {
    final int totalLimitSecs = (_kidsLimitMinutes * 60).clamp(1, 86400);
    final int remSecs = _kidsRemainingSeconds.clamp(0, totalLimitSecs);
    final int mins = remSecs ~/ 60;
    final int secs = remSecs % 60;
    final String formattedTimer =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final double ratio = (remSecs / totalLimitSecs).clamp(0.0, 1.0);
    final bool isTimeUp = remSecs <= 0;
    final Color timerColor = isTimeUp
        ? AppTheme.glitchCoral
        : (remSecs <= 300 ? AppTheme.warningAmber : AppTheme.cyan);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Main Active Kids Mode Countdown Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: timerColor.withValues(alpha: 0.6), width: 1.5),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: timerColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: timerColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  isTimeUp ? '⏰ KIDS TIME FINISHED' : '🧸 KIDS MODE ACTIVE',
                  style: TextStyle(
                    color: timerColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                formattedTimer,
                style: TextStyle(
                  color: timerColor,
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isTimeUp
                    ? 'Allowed screen time is up! Return phone to parent.'
                    : 'Remaining out of $_kidsLimitMinutes minutes allowed',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 10,
                  backgroundColor: AppTheme.background,
                  valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_outlined, color: AppTheme.mint, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Adult Dashboard, Settings & Daily Limit are paused and protected while Kids Mode is active.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Allowed Apps Summary Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Allowed Apps for Kids',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.glitchCoral.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '🔒 Others Locked',
                      style: TextStyle(
                        color: AppTheme.glitchCoral,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_kidsAllowedPackages.isEmpty)
                const Text(
                  'No apps allowed in this session.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _kidsAllowedPackages.map((pkg) {
                    final appName = _installedAppNames[pkg] ?? SocialApps.getAppName(pkg);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.cyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppTheme.cyan, size: 15),
                          const SizedBox(width: 6),
                          Text(
                            appName,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Parent Unlock Button (Requires 4-Digit Parent PIN)
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mint,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: _unlockAndEndKidsMode,
            icon: const Icon(Icons.lock_open_rounded, size: 22),
            label: const Text(
              'Parent Unlock (End Kids Mode)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/usage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/social_apps.dart';
import '../../main.dart';
import 'home_dashboard.dart';
import 'app_selection_screen.dart';

class OnboardingDisclosureScreen extends StatefulWidget {
  const OnboardingDisclosureScreen({super.key});

  @override
  State<OnboardingDisclosureScreen> createState() => _OnboardingDisclosureScreenState();
}

class _OnboardingDisclosureScreenState extends State<OnboardingDisclosureScreen>
    with WidgetsBindingObserver {
  // Step 0: Permissions, Step 1: Initial Setup Wizard
  int _currentStep = 0;
  final ScrollController _permissionsScrollController = ScrollController();
  final ScrollController _preferencesScrollController = ScrollController();
  final GlobalKey _dailyLimitKey = GlobalKey();
  final GlobalKey _bypassDurationKey = GlobalKey();
  bool _hasAutoScrolledToRecommended = false;

  bool _hasUsageAccess = false;
  bool _hasOverlayPermission = false;
  bool _hasNotificationPermission = false;
  bool _hasBatteryExemption = false;

  // Initial Setup Choices (null by default so both modes are highlighted and user chooses)
  int? _selectedMode; // Nullable: 0 for Awareness, 1 for Limit Mode
  int? _selectedDailyLimit; // Nullable: user must explicitly choose a limit
  int? _selectedBypassDuration; // Nullable: user must explicitly choose a bypass duration

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCurrentPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _permissionsScrollController.dispose();
    _preferencesScrollController.dispose();
    super.dispose();
  }

  void _scrollToBypassDuration() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentContext = _bypassDurationKey.currentContext;
      if (currentContext != null) {
        Scrollable.ensureVisible(
          currentContext,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
          alignment: 0.9,
        );
      } else if (_preferencesScrollController.hasClients) {
        _preferencesScrollController.animateTo(
          _preferencesScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _scrollToDailyLimit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentContext = _dailyLimitKey.currentContext;
      if (currentContext != null) {
        Scrollable.ensureVisible(
          currentContext,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
          alignment: 0.3,
        );
      }
    });
  }

  // Automatically refresh permissions when returning from Android Settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkCurrentPermissions();
    }
  }

  Future<void> _checkCurrentPermissions() async {
    final usage = await UsageService.checkUsagePermission();
    final overlay = await UsageService.checkOverlayPermission();
    final notification = await UsageService.checkNotificationPermission();
    final battery = await UsageService.checkBatteryExemption();

    if (mounted) {
      final wasReadyBefore = _hasUsageAccess && _hasOverlayPermission;
      final isReadyNow = usage && overlay;

      setState(() {
        _hasUsageAccess = usage;
        _hasOverlayPermission = overlay;
        _hasNotificationPermission = notification;
        _hasBatteryExemption = battery;
      });

      // When the 2 required permissions are newly unlocked, smoothly glide down
      // so the Recommended section and 4th card are brought into view above the bottom bar.
      if (!wasReadyBefore && isReadyNow && !_hasAutoScrolledToRecommended) {
        _hasAutoScrolledToRecommended = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_permissionsScrollController.hasClients) {
            _permissionsScrollController.animateTo(
              _permissionsScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    }
  }

  void _showProminentDisclosureModal({
    required String title,
    required String message,
    required VoidCallback onGranted,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 22,
              right: 22,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.mint.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.privacy_tip_outlined, color: AppTheme.mint, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.cardBorder, width: 1),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.mint,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onGranted();
                    },
                    child: const Text(
                      'I Understand & Allow',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleGrantUsage() async {
    _showProminentDisclosureModal(
      title: 'Usage Access Permission',
      message:
          'DefogMind uses Usage Access solely to detect when a selected app is open and track its screen time on your phone. All data stays 100% on your device and is never shared.',
      onGranted: () async {
        await UsageService.requestUsagePermission();
      },
    );
  }

  Future<void> _handleGrantOverlay() async {
    _showProminentDisclosureModal(
      title: 'Display Over Apps Permission',
      message:
          'DefogMind uses Display Over Other Apps solely to show your focus shield and Brain Fog indicator over monitored apps. No screen content is ever read or collected.',
      onGranted: () async {
        await UsageService.requestOverlayPermission();
      },
    );
  }

  Future<void> _handleGrantNotification() async {
    await UsageService.requestNotificationPermission();
  }

  Future<void> _handleGrantBattery() async {
    await UsageService.requestBatteryExemption();
  }

  bool _isLaunching = false;

  Future<void> _proceedToAppSelection() async {
    if (_isLaunching) return;
    setState(() => _isLaunching = true);

    final int chosenMode = _selectedMode ?? 1;
    final int finalDailyLimit = _selectedDailyLimit ?? 60;
    final int finalBypassDuration = _selectedBypassDuration ?? 300;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('focus_mode', chosenMode);
      await prefs.setInt('daily_limit_minutes', finalDailyLimit);
      await prefs.setInt('oxygen_pass_duration_seconds', finalBypassDuration);
    } catch (_) {
      // Ensure navigation proceeds even if a platform call throws
    }

    if (!mounted) return;
    setState(() => _isLaunching = false);
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const AppSelectionScreen(isOnboarding: true),
      ),
    );

    // If user completed Step 2 (App Selection), advance to Step 3 (Privacy & Permissions)
    if (result == true && mounted) {
      setState(() => _currentStep = 1);
    }
  }

  Future<void> _finishSetupAndLaunch() async {
    if (_isLaunching) return;
    setState(() => _isLaunching = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      final int chosenMode = prefs.getInt('focus_mode') ?? (_selectedMode ?? 1);
      final int finalDailyLimit = prefs.getInt('daily_limit_minutes') ?? (_selectedDailyLimit ?? 60);
      final int finalBypassDuration = prefs.getInt('oxygen_pass_duration_seconds') ?? (_selectedBypassDuration ?? 300);
      final packages = prefs.getStringList('monitored_packages') ?? SocialApps.defaultPackageList;

      // Start native focus service in background without blocking UI navigation
      UsageService.startFocusService(
        mode: chosenMode,
        passDuration: finalBypassDuration,
        dailyLimit: finalDailyLimit,
        packages: packages,
      );
    } catch (_) {
      // Ensure navigation proceeds even if a platform call throws
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeDashboard()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentStep == 1) {
          setState(() => _currentStep = 0);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: _currentStep == 0 ? _buildPreferencesStep() : _buildPermissionsStep(),
        ),
      ),
    );
  }

  Widget _buildPermissionsStep() {
    final bool canProceed = _hasUsageAccess && _hasOverlayPermission;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _permissionsScrollController,
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.mint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.mint.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'STEP 3 OF 3 • PRIVACY & PERMISSIONS',
                    style: TextStyle(
                      color: AppTheme.mint,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Activate DefogMind',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Allow permissions to locally track your selected apps and show your focus shield.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 14),

                // Prominent On-Device Privacy & Data Safety Banner (Above the Fold)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.35), width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.verified_user_outlined, color: AppTheme.cyan, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '100% On-Device Privacy Guarantee',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your app usage and screen-time data never leave your phone. All tracking is processed 100% locally on your device—we never collect, upload, or share your personal data with any external server.',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11.5,
                                height: 1.38,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  'REQUIRED',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 5),

                _buildPermissionCard(
                  icon: Icons.query_stats,
                  title: 'Usage Access',
                  description: 'Required to read foreground app duration locally.',
                  isGranted: _hasUsageAccess,
                  onTap: _handleGrantUsage,
                ),
                const SizedBox(height: 8),
                _buildPermissionCard(
                  icon: Icons.layers_outlined,
                  title: 'Display Over Other Apps',
                  description: 'Shows your focus shield & movable Brain Fog Meter.',
                  isGranted: _hasOverlayPermission,
                  onTap: _handleGrantOverlay,
                ),
                const SizedBox(height: 10),

                Text(
                  'RECOMMENDED',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 5),

                _buildPermissionCard(
                  icon: Icons.battery_saver_outlined,
                  title: 'Background Protection',
                  description: 'Prevents system battery saver from closing DefogMind.',
                  isGranted: _hasBatteryExemption,
                  onTap: _handleGrantBattery,
                ),
                const SizedBox(height: 8),
                _buildPermissionCard(
                  icon: Icons.notifications_active_outlined,
                  title: 'Focus Notifications',
                  description: 'Keeps the persistent low-priority focus monitor alive.',
                  isGranted: _hasNotificationPermission,
                  onTap: _handleGrantNotification,
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
        // Sticky Bottom CTA Bar (Disclaimer + Action Button always visible above the fold)
        Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          decoration: BoxDecoration(
            color: AppTheme.background,
            border: Border(top: BorderSide(color: AppTheme.cardBorder, width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DefogMind is a digital habit and productivity utility. It does not provide medical advice, diagnosis, or treatment for cognitive conditions.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 9.5, height: 1.25),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canProceed ? AppTheme.mint : AppTheme.surfaceCard,
                    foregroundColor: canProceed ? Colors.black : AppTheme.textMuted,
                    disabledBackgroundColor: _isLaunching ? AppTheme.mint : AppTheme.surfaceCard,
                    disabledForegroundColor: _isLaunching ? Colors.black : AppTheme.textMuted,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: (canProceed || _isLaunching) ? AppTheme.mint : AppTheme.cardBorder,
                        width: 1,
                      ),
                    ),
                  ),
                  onPressed: (canProceed && !_isLaunching) ? _finishSetupAndLaunch : null,
                  child: _isLaunching
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Starting DefogMind...',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          canProceed ? 'Start Using DefogMind' : 'Allow Required Permissions to Continue',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesStep() {
    final bool isDailySelected = _selectedDailyLimit != null;
    final bool isBypassSelected = _selectedBypassDuration != null;

    final bool canStart = _selectedMode == 0 ||
        (_selectedMode == 1 && isDailySelected && isBypassSelected);

    // Card 1 is active if Limit Mode is selected and Card 1 is not yet chosen
    final bool isDailyActive = _selectedMode == 1 && !isDailySelected;

    // Card 2 is active ONLY IF Limit Mode is selected, Card 1 IS chosen, and Card 2 is not yet chosen
    // If the user chooses Card 2 first, isBypassSelected is true so isBypassActive stays false!
    final bool isBypassActive = _selectedMode == 1 && isDailySelected && !isBypassSelected;

    String buttonLabel;
    if (_selectedMode == null) {
      buttonLabel = 'Choose a Focus Mode Above';
    } else if (_selectedMode == 0) {
      buttonLabel = 'Next: Select Apps to Track';
    } else if (!isDailySelected) {
      buttonLabel = 'Select Daily Limit Above';
    } else if (!isBypassSelected) {
      buttonLabel = 'Select Extra Unlock Time Above';
    } else {
      buttonLabel = 'Next: Select Apps to Track';
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _preferencesScrollController,
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.cyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'STEP 1 OF 3 • FOCUS STYLE',
                        style: TextStyle(
                          color: AppTheme.cyan,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    _buildThemeQuickSwitch(),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'How do you want to focus?',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose your preferred focus style. You can change this anytime in Settings.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),

                // Both mode options are clearly displayed and highlighted
                _buildModeOption(
                  mode: 1,
                  title: 'Limit Mode (Recommended)',
                  description: 'Strict blocking. When your daily limit is reached, a focus shield blocks the selected apps.',
                  icon: Icons.shield_outlined,
                ),
                const SizedBox(height: 12),
                _buildModeOption(
                  mode: 0,
                  title: 'Awareness Mode',
                  description: 'No app blocking. Shows a small floating meter (🧠 Fresh, Tired, etc.) on screen while using selected apps.',
                  icon: Icons.visibility_outlined,
                ),

                // If Awareness Mode is chosen: clean confirmation note
                if (_selectedMode == 0) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.mint.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.mint.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: AppTheme.mint, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Awareness Mode selected! DefogMind will monitor your selected apps screen time without locking you from using them.',
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 12.5, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // If Limit Mode is chosen: guided settings with animated moving comet border
                if (_selectedMode == 1) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DAILY SOCIAL LIMIT',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (isDailySelected)
                        Text(
                          '$_selectedDailyLimit mins',
                          style: const TextStyle(
                            color: AppTheme.mint,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _MovingCometBorderCard(
                    key: _dailyLimitKey,
                    isActive: isDailyActive,
                    isCompleted: isDailySelected,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Daily Limit',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _selectedDailyLimit != null ? '$_selectedDailyLimit mins' : 'Select below',
                                style: TextStyle(
                                  color: _selectedDailyLimit != null ? AppTheme.mint : AppTheme.cyan,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [30, 60, 90, 120, 180, 240].map((mins) {
                              final isSelected = _selectedDailyLimit == mins;
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _selectedDailyLimit = mins);
                                  if (_selectedBypassDuration == null) {
                                    _scrollToBypassDuration();
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.mint.withValues(alpha: 0.18) : AppTheme.background,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? AppTheme.mint : AppTheme.cardBorder,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    '${mins}m',
                                    style: TextStyle(
                                      color: isSelected ? AppTheme.mint : AppTheme.textSecondary,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                          Slider(
                            value: (_selectedDailyLimit ?? 60).toDouble(),
                            min: 15,
                            max: 240,
                            divisions: 15,
                            activeColor: _selectedDailyLimit != null ? AppTheme.mint : AppTheme.cyan,
                            inactiveColor: AppTheme.background,
                            onChanged: (val) => setState(() => _selectedDailyLimit = val.toInt()),
                            onChangeEnd: (val) {
                              if (_selectedBypassDuration == null) {
                                _scrollToBypassDuration();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EXTRA UNLOCK TIME',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (isBypassSelected)
                        Text(
                          '${(_selectedBypassDuration ?? 0) ~/ 60} mins',
                          style: const TextStyle(
                            color: AppTheme.mint,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _MovingCometBorderCard(
                    key: _bypassDurationKey,
                    isActive: isBypassActive,
                    isCompleted: isBypassSelected,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _buildDurationOption('2 Min', 120),
                          const SizedBox(width: 8),
                          _buildDurationOption('5 Min', 300),
                          const SizedBox(width: 8),
                          _buildDurationOption('10 Min', 600),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
        // Sticky Bottom CTA Bar
        Container(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
          decoration: BoxDecoration(
            color: AppTheme.background,
            border: Border(top: BorderSide(color: AppTheme.cardBorder, width: 1)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: canStart ? AppTheme.mint : AppTheme.surfaceCard,
                foregroundColor: canStart ? Colors.black : AppTheme.textMuted,
                disabledBackgroundColor: _isLaunching ? AppTheme.mint : AppTheme.surfaceCard,
                disabledForegroundColor: _isLaunching ? Colors.black : AppTheme.textMuted,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: (canStart || _isLaunching) ? AppTheme.mint : AppTheme.cardBorder,
                    width: 1,
                  ),
                ),
              ),
              onPressed: (canStart && !_isLaunching) ? _proceedToAppSelection : null,
              child: _isLaunching
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Loading Apps...',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      buttonLabel,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeOption({
    required int mode,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedMode = mode);
        if (mode == 1 && _selectedDailyLimit == null) {
          _scrollToDailyLimit();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.mint.withValues(alpha: 0.12) : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppTheme.mint : AppTheme.cardBorder,
            width: isSelected ? 1.8 : 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.mint.withValues(alpha: 0.15) : AppTheme.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppTheme.mint : AppTheme.cyan,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: isSelected ? AppTheme.textSecondary : AppTheme.textMuted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? AppTheme.mint : AppTheme.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeQuickSwitch() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeModeNotifier,
      builder: (context, currentMode, _) {
        final isDarkTheme = AppTheme.isDark;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: isDarkTheme ? AppTheme.surfaceCard : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkTheme ? AppTheme.cardBorder : const Color(0xFFCBD5E1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeIconBtn(
                mode: ThemeMode.system,
                icon: Icons.brightness_auto_outlined,
                tooltip: 'System',
                isSelected: currentMode == ThemeMode.system,
              ),
              _buildThemeIconBtn(
                mode: ThemeMode.light,
                icon: Icons.light_mode_outlined,
                tooltip: 'Light',
                isSelected: currentMode == ThemeMode.light,
              ),
              _buildThemeIconBtn(
                mode: ThemeMode.dark,
                icon: Icons.dark_mode_outlined,
                tooltip: 'Dark',
                isSelected: currentMode == ThemeMode.dark,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeIconBtn({
    required ThemeMode mode,
    required IconData icon,
    required String tooltip,
    required bool isSelected,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => updateAppThemeMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.mint : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 15,
            color: isSelected
                ? Colors.black
                : (AppTheme.isDark ? AppTheme.textSecondary : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationOption(String label, int seconds) {
    final isSelected = _selectedBypassDuration == seconds;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedBypassDuration = seconds);
          if (_selectedDailyLimit == null) {
            _scrollToDailyLimit();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.mint.withValues(alpha: 0.18) : AppTheme.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.mint : AppTheme.cardBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.mint : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGranted ? AppTheme.mint.withValues(alpha: 0.4) : AppTheme.cardBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isGranted ? AppTheme.mint.withValues(alpha: 0.12) : AppTheme.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isGranted ? AppTheme.mint : AppTheme.textSecondary,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  description,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isGranted)
            const Icon(Icons.check_circle, color: AppTheme.mint, size: 22)
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.background,
                foregroundColor: AppTheme.mint,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppTheme.mint, width: 1),
                ),
              ),
              onPressed: onTap,
              child: const Text('Allow', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

/// Animated card with a circulating comet / traveling beam of light around its rounded perimeter.
class _MovingCometBorderCard extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final bool isCompleted;
  final double borderRadius;
  final double strokeWidth;
  final Color? backgroundColor;

  const _MovingCometBorderCard({
    super.key,
    required this.child,
    required this.isActive,
    this.isCompleted = false,
    this.borderRadius = 18.0,
    this.strokeWidth = 2.5,
    this.backgroundColor,
  });

  @override
  State<_MovingCometBorderCard> createState() => _MovingCometBorderCardState();
}

class _MovingCometBorderCardState extends State<_MovingCometBorderCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _MovingCometBorderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        if (!_controller.isAnimating) _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return Container(
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: widget.isCompleted
                ? AppTheme.mint.withValues(alpha: 0.65)
                : AppTheme.cardBorder,
            width: widget.isCompleted ? 1.5 : 1.0,
          ),
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          foregroundPainter: _MovingCometBorderPainter(
            progress: _controller.value,
            radius: widget.borderRadius,
            strokeWidth: widget.strokeWidth,
            headColor: Colors.white,
            glowColor: AppTheme.cyan,
            tailColor: AppTheme.mint,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: AppTheme.cardBorder.withValues(alpha: 0.6),
                width: 1.0,
              ),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _MovingCometBorderPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final double radius;
  final double strokeWidth;
  final Color headColor;
  final Color glowColor;
  final Color tailColor;

  _MovingCometBorderPainter({
    required this.progress,
    required this.radius,
    required this.strokeWidth,
    required this.headColor,
    required this.glowColor,
    required this.tailColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final totalLength = metric.length;

    // Comet beam covers 35% of the perimeter
    final beamLength = totalLength * 0.35;
    final currentPos = progress * totalLength;

    // Draw fading tail to head in 22 smooth segments
    const int steps = 22;
    for (int i = 0; i < steps; i++) {
      final double fractionStart = i / steps;
      final double fractionEnd = (i + 1) / steps;

      final double segStart = (currentPos - beamLength + (fractionStart * beamLength)) % totalLength;
      final double segEnd = (currentPos - beamLength + (fractionEnd * beamLength)) % totalLength;

      // t goes from 0.0 (tail tip) to 1.0 (head)
      final double t = (i + 1) / steps;
      final double opacity = math.pow(t, 1.8).toDouble().clamp(0.0, 1.0);

      // Height/thickness: starts thin from behind (0.8px) and goes wider/higher at front (strokeWidth + 0.8px)
      final double width = 0.8 + (strokeWidth * t);

      final Color segColor = Color.lerp(tailColor, glowColor, t)!.withValues(alpha: opacity);

      final paint = Paint()
        ..color = segColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = i == steps - 1 ? StrokeCap.round : StrokeCap.butt;

      if (segStart < segEnd) {
        canvas.drawPath(metric.extractPath(segStart, segEnd), paint);
      } else {
        canvas.drawPath(metric.extractPath(segStart, totalLength), paint);
        canvas.drawPath(metric.extractPath(0, segEnd), paint);
      }
    }

    // Glowing comet head (leading point) with glowing aura and white core
    final tangent = metric.getTangentForOffset(currentPos % totalLength);
    if (tangent != null) {
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      canvas.drawCircle(tangent.position, strokeWidth * 1.8, glowPaint);

      final corePaint = Paint()
        ..color = headColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tangent.position, strokeWidth * 0.9, corePaint);
    }
  }

  @override
  bool shouldRepaint(_MovingCometBorderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

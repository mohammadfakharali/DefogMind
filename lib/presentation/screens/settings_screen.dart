import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/social_apps.dart';
import '../../core/theme/app_theme.dart';
import '../../services/oxygen_pass_manager.dart';
import '../../services/usage_service.dart';
import '../../services/admob_service.dart';
import '../../main.dart';
import '../widgets/math_challenge_dialog.dart';
import 'app_selection_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _passDurationSeconds = 300;
  int _dailyLimitMinutes = 60;
  int _remainingPasses = 2;
  int _focusMode = 1;
  bool _isAdultTrackingEnabled = true;

  // Committed baseline values to detect unsaved draft changes
  int _savedPassDurationSeconds = 300;
  int _savedDailyLimitMinutes = 60;
  int _savedFocusMode = 1;
  bool _savedAdultTrackingEnabled = true;

  List<String> _monitoredPackages = SocialApps.defaultPackageList;
  bool _isNavigatingToApps = false;
  bool _isLoading = true;

  bool get _hasUnsavedChanges =>
      _passDurationSeconds != _savedPassDurationSeconds ||
      _dailyLimitMinutes != _savedDailyLimitMinutes ||
      _focusMode != _savedFocusMode ||
      _isAdultTrackingEnabled != _savedAdultTrackingEnabled;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final duration = prefs.getInt('oxygen_pass_duration_seconds') ?? 300;
    final limit = prefs.getInt('daily_limit_minutes') ?? 60;
    final mode = prefs.getInt('focus_mode') ?? 1;
    final adultEnabled = prefs.getBool('adult_tracking_enabled') ?? true;
    final packages = prefs.getStringList('monitored_packages') ?? SocialApps.defaultPackageList;
    final passes = await OxygenPassManager.getRemainingPasses();

    if (mounted) {
      setState(() {
        _passDurationSeconds = duration;
        _dailyLimitMinutes = limit;
        _focusMode = mode;
        _isAdultTrackingEnabled = adultEnabled;

        _savedPassDurationSeconds = duration;
        _savedDailyLimitMinutes = limit;
        _savedFocusMode = mode;
        _savedAdultTrackingEnabled = adultEnabled;

        _monitoredPackages = packages;
        _remainingPasses = passes;
        _isLoading = false;
      });
    }
  }

  void _toggleAdultTracking(bool enabled) {
    setState(() => _isAdultTrackingEnabled = enabled);
  }

  void _changeFocusMode(int targetMode) {
    if (targetMode == _focusMode) return;
    setState(() => _focusMode = targetMode);
  }

  void _updateDuration(int seconds) {
    setState(() => _passDurationSeconds = seconds);
  }

  void _updateLimit(int minutes) {
    setState(() => _dailyLimitMinutes = minutes);
  }

  void _onSavePressed() {
    if (!_hasUnsavedChanges) return;
    MathChallengeDialog.show(
      context: context,
      actionDescription: 'save settings changes',
      onSolved: _commitSettings,
    );
  }

  Future<void> _commitSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('focus_mode', _focusMode);
    await prefs.setBool('adult_tracking_enabled', _isAdultTrackingEnabled);
    await prefs.setInt('daily_limit_minutes', _dailyLimitMinutes);
    await OxygenPassManager.setPassDuration(_passDurationSeconds);

    await _syncWithNativeService();

    if (mounted) {
      setState(() {
        _savedFocusMode = _focusMode;
        _savedAdultTrackingEnabled = _isAdultTrackingEnabled;
        _savedDailyLimitMinutes = _dailyLimitMinutes;
        _savedPassDurationSeconds = _passDurationSeconds;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: AppTheme.mint,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _syncWithNativeService() async {
    final prefs = await SharedPreferences.getInstance();
    final packages = prefs.getStringList('monitored_packages') ?? _monitoredPackages;

    await UsageService.updateServiceConfig(
      mode: _focusMode,
      adultTrackingEnabled: _isAdultTrackingEnabled,
      passDuration: _passDurationSeconds,
      dailyLimit: _dailyLimitMinutes,
      packages: packages,
    );

    AdMobService.instance.showInterstitialIfAllowed();
  }

  void _watchRewardedAdForBonusPass() {
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video ad is loading. Please retry in a few seconds.'),
              backgroundColor: AppTheme.warningAmber,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Settings & Focus Engine'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.mint))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Master App Tracking Switch (Allows pausing own tracking while keeping Kids Mode available)
                _buildSectionHeader('MY APP TRACKING'),
                const SizedBox(height: 8),
                _buildAdultTrackingToggleCard(),
                const SizedBox(height: 22),

                // Theme Mode Row (Immediate switch, no math required)
                _buildSectionHeader('APP THEME'),
                const SizedBox(height: 8),
                _buildThemeSelectorCard(),
                const SizedBox(height: 22),

                Opacity(
                  opacity: _isAdultTrackingEnabled ? 1.0 : 0.38,
                  child: IgnorePointer(
                    ignoring: !_isAdultTrackingEnabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Focus Mode Selector
                        _buildSectionHeader('FOCUS MODE'),
                        const SizedBox(height: 8),
                        _buildModeSelector(),
                        const SizedBox(height: 22),

                        // Monitored Apps
                        _buildSectionHeader('MONITORED SOCIAL APPS'),
                        const SizedBox(height: 8),
                        _buildMonitoredAppsTile(),
                        const SizedBox(height: 22),

                        // Daily Limit (Locked in Awareness Mode)
                        _buildSectionHeader('DAILY SOCIAL LIMIT'),
                        const SizedBox(height: 8),
                        _buildDetoxOnlyWrapper(
                          explanation: 'Awareness Mode tracks time without hard limits.',
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceCard,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Daily Limit Target',
                                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                    Text(
                                      '$_dailyLimitMinutes mins',
                                      style: const TextStyle(color: AppTheme.mint, fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [30, 60, 90, 120, 180, 240].map((mins) {
                                    final isSelected = _dailyLimitMinutes == mins;
                                    return GestureDetector(
                                      onTap: () => _updateLimit(mins),
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
                                  value: _dailyLimitMinutes.toDouble().clamp(15.0, 240.0),
                                  min: 15,
                                  max: 240,
                                  divisions: 15,
                                  activeColor: AppTheme.mint,
                                  inactiveColor: AppTheme.background,
                                  onChanged: (val) {
                                    _updateLimit(val.round());
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Extra Unlock Time Selector (Locked in Awareness Mode)
                        _buildSectionHeader('EXTRA UNLOCK TIME'),
                        const SizedBox(height: 8),
                        _buildDetoxOnlyWrapper(
                          explanation: 'Extra unlock passes only apply in Limit Mode.',
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceCard,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Active time granted per extra unlock:',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    _buildDurationOption('2 Min', 120),
                                    const SizedBox(width: 8),
                                    _buildDurationOption('5 Min', 300),
                                    const SizedBox(width: 8),
                                    _buildDurationOption('10 Min', 600),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Note: Dual-clock engine pauses when social app is closed, with a 15-minute absolute ceiling.',
                                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Extra Unlock Pass Balance & Rewarded Ad Bonus (Locked in Awareness Mode)
                        _buildSectionHeader('EXTRA UNLOCK PASSES'),
                        const SizedBox(height: 8),
                        _buildDetoxOnlyWrapper(
                          explanation: 'Extra unlock passes only apply in Limit Mode.',
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceCard,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.mint.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.bolt,
                                    color: _remainingPasses > 0 ? AppTheme.mint : AppTheme.warningAmber,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _remainingPasses > 0
                                            ? '$_remainingPasses Passes Left Today'
                                            : 'No Passes Left • Earn Pass',
                                        style: TextStyle(
                                          color: _remainingPasses > 0 ? AppTheme.textPrimary : AppTheme.warningAmber,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '2 free resets daily at midnight',
                                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _remainingPasses > 0 ? AppTheme.background : AppTheme.cyan.withValues(alpha: 0.15),
                                    foregroundColor: AppTheme.cyan,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: const BorderSide(color: AppTheme.cyan),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  onPressed: _watchRewardedAdForBonusPass,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.video_library_outlined, size: 15),
                                      const SizedBox(width: 5),
                                      Text(
                                        _remainingPasses > 0 ? '+1 Pass' : 'Earn Pass',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Background Protection
                _buildSectionHeader('BACKGROUND PROTECTION'),
                const SizedBox(height: 8),
                ListTile(
                  tileColor: AppTheme.surfaceCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppTheme.cardBorder),
                  ),
                  leading: const Icon(Icons.battery_saver_outlined, color: AppTheme.mint),
                  title: Text('Battery Optimization Exemption', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13.5)),
                  subtitle: Text('Allow DefogMind to stay active when recent apps are cleared', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  trailing: Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  onTap: () async {
                    await UsageService.requestBatteryExemption();
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  tileColor: AppTheme.surfaceCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppTheme.cardBorder),
                  ),
                  leading: const Icon(Icons.settings_suggest_outlined, color: AppTheme.cyan),
                  title: Text('Device Background Management', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13.5)),
                  subtitle: Text('Allow background start and auto-launch permissions', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  trailing: Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  onTap: () async {
                    await UsageService.openAutoStartSettings();
                  },
                ),
                const SizedBox(height: 32),

                // Medical Disclaimer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Text(
                    'DefogMind is a digital habit and productivity utility. It does not provide medical advice, diagnosis, or treatment for cognitive conditions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  border: Border(top: BorderSide(color: AppTheme.cardBorder, width: 1)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasUnsavedChanges ? AppTheme.mint : AppTheme.surfaceCard,
                      foregroundColor: _hasUnsavedChanges ? Colors.black : AppTheme.textMuted,
                      disabledBackgroundColor: AppTheme.surfaceCard,
                      disabledForegroundColor: AppTheme.textMuted,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: _hasUnsavedChanges ? AppTheme.mint : AppTheme.cardBorder,
                        ),
                      ),
                    ),
                    onPressed: _hasUnsavedChanges ? _onSavePressed : null,
                    child: Text(
                      _hasUnsavedChanges ? 'Save Settings' : 'All Settings Saved',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildAdultTrackingToggleCard() {
    final Color accentColor = _isAdultTrackingEnabled ? AppTheme.mint : AppTheme.warningAmber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isAdultTrackingEnabled
              ? AppTheme.mint.withValues(alpha: 0.35)
              : AppTheme.warningAmber.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isAdultTrackingEnabled ? Icons.psychology_outlined : Icons.pause_circle_outline,
              color: accentColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'My App Tracking',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _isAdultTrackingEnabled ? 'ON' : 'OFF',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _isAdultTrackingEnabled
                      ? 'Active • Monitoring your apps & Brain Fog'
                      : 'Paused • Kids Mode still works anytime',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAdultTrackingEnabled,
            activeThumbColor: AppTheme.mint,
            activeTrackColor: AppTheme.mint.withValues(alpha: 0.25),
            onChanged: _toggleAdultTracking,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelectorCard() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeModeNotifier,
      builder: (context, currentMode, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appearance',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Customize app look and feel',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildThemeOptionTab(
                    mode: ThemeMode.system,
                    label: 'System',
                    icon: Icons.brightness_auto_outlined,
                    isSelected: currentMode == ThemeMode.system,
                  ),
                  const SizedBox(width: 8),
                  _buildThemeOptionTab(
                    mode: ThemeMode.light,
                    label: 'Light',
                    icon: Icons.light_mode_outlined,
                    isSelected: currentMode == ThemeMode.light,
                  ),
                  const SizedBox(width: 8),
                  _buildThemeOptionTab(
                    mode: ThemeMode.dark,
                    label: 'Dark',
                    icon: Icons.dark_mode_outlined,
                    isSelected: currentMode == ThemeMode.dark,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOptionTab({
    required ThemeMode mode,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    final isDark = AppTheme.isDark;
    final unselectedBg = isDark ? const Color(0xFF0B0F17) : const Color(0xFFF1F5F9);
    final unselectedBorder = isDark ? AppTheme.cardBorder : const Color(0xFFCBD5E1);
    final unselectedText = isDark ? AppTheme.textSecondary : const Color(0xFF475569);

    return Expanded(
      child: GestureDetector(
        onTap: () => updateAppThemeMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.mint.withValues(alpha: 0.18) : unselectedBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.mint : unselectedBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppTheme.mint : unselectedText,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppTheme.mint : unselectedText,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
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
            subtitle: 'Blocks apps at limit',
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

  Widget _buildMonitoredAppsTile() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.mint.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.apps_outlined, color: AppTheme.mint, size: 22),
        ),
        title: Text(
          'Manage Monitored Apps',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          _isNavigatingToApps ? 'Loading installed apps...' : '${_monitoredPackages.length} social apps configured',
          style: TextStyle(
            color: _isNavigatingToApps ? AppTheme.mint : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: _isNavigatingToApps ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        trailing: _isNavigatingToApps
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.mint),
              )
            : Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        onTap: _isNavigatingToApps
            ? null
            : () async {
                setState(() => _isNavigatingToApps = true);
                final updated = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AppSelectionScreen()),
                );
                if (mounted) setState(() => _isNavigatingToApps = false);
                if (updated == true && mounted) {
                  final prefs = await SharedPreferences.getInstance();
                  final packages = prefs.getStringList('monitored_packages') ?? SocialApps.defaultPackageList;
                  if (mounted) setState(() => _monitoredPackages = packages);
                }
              },
      ),
    );
  }

  Widget _buildDetoxOnlyWrapper({
    required Widget child,
    required String explanation,
  }) {
    final isLocked = _focusMode == 0;
    if (!isLocked) return child;

    return Stack(
      children: [
        Opacity(
          opacity: 0.35,
          child: IgnorePointer(
            ignoring: true,
            child: child,
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 16, color: AppTheme.warningAmber),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Limit Mode Only: $explanation',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationOption(String label, int seconds) {
    final isSelected = _passDurationSeconds == seconds;
    return Expanded(
      child: GestureDetector(
        onTap: () => _updateDuration(seconds),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.mint.withValues(alpha: 0.15) : AppTheme.background,
            borderRadius: BorderRadius.circular(12),
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
}

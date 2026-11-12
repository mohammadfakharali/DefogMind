import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'services/usage_service.dart';
import 'presentation/screens/onboarding_disclosure_screen.dart';
import 'presentation/screens/home_dashboard.dart';

// Global Theme Notifier for instant dynamic theme changes across the app
final ValueNotifier<ThemeMode> appThemeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved theme preference: 'system' (default), 'light', or 'dark'
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('app_theme_mode') ?? 'system';
  if (savedTheme == 'light') {
    appThemeModeNotifier.value = ThemeMode.light;
    AppTheme.setBrightness(Brightness.light);
  } else if (savedTheme == 'dark') {
    appThemeModeNotifier.value = ThemeMode.dark;
    AppTheme.setBrightness(Brightness.dark);
  } else {
    appThemeModeNotifier.value = ThemeMode.system;
    final platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    AppTheme.setBrightness(platformBrightness);
  }

  runApp(const DefogMindRootApp());
}

Future<void> updateAppThemeMode(ThemeMode mode) async {
  appThemeModeNotifier.value = mode;
  final prefs = await SharedPreferences.getInstance();
  final String modeStr = mode == ThemeMode.light
      ? 'light'
      : (mode == ThemeMode.dark ? 'dark' : 'system');
  await prefs.setString('app_theme_mode', modeStr);

  if (mode == ThemeMode.light) {
    AppTheme.setBrightness(Brightness.light);
  } else if (mode == ThemeMode.dark) {
    AppTheme.setBrightness(Brightness.dark);
  } else {
    AppTheme.setBrightness(WidgetsBinding.instance.platformDispatcher.platformBrightness);
  }
}

class DefogMindRootApp extends StatefulWidget {
  const DefogMindRootApp({super.key});

  @override
  State<DefogMindRootApp> createState() => _DefogMindRootAppState();
}

class _DefogMindRootAppState extends State<DefogMindRootApp> {
  bool _isChecking = true;
  bool _needsOnboarding = true;

  @override
  void initState() {
    super.initState();
    _initializeAppAndPermissions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache the small logo asset on the very first frame so it never pops in blank
    precacheImage(const AssetImage('assets/images/app_logo.png'), context);
  }

  Future<void> _initializeAppAndPermissions() async {
    bool completedBefore = false;
    bool hasUsage = true;
    bool hasOverlay = true;

    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(milliseconds: 1000));
      completedBefore = prefs.getBool('onboarding_completed') ?? false;
    } catch (_) {
      completedBefore = false;
    }

    try {
      final results = await Future.wait([
        UsageService.checkUsagePermission(),
        UsageService.checkOverlayPermission(),
      ]).timeout(const Duration(milliseconds: 1000));
      hasUsage = results[0];
      hasOverlay = results[1];
    } catch (_) {
      hasUsage = completedBefore;
      hasOverlay = completedBefore;
    }

    if (!completedBefore && hasUsage && hasOverlay) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.containsKey('focus_mode')) {
          completedBefore = true;
          await prefs.setBool('onboarding_completed', true);
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _needsOnboarding = !completedBefore || !hasUsage || !hasOverlay;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeModeNotifier,
      builder: (context, currentThemeMode, _) {
        final platformBrightness = MediaQuery.platformBrightnessOf(context);
        final effectiveBrightness = currentThemeMode == ThemeMode.system
            ? platformBrightness
            : (currentThemeMode == ThemeMode.dark ? Brightness.dark : Brightness.light);

        AppTheme.setBrightness(effectiveBrightness);

        final bool isEffectiveDark = effectiveBrightness == Brightness.dark;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isEffectiveDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: isEffectiveDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC),
            systemNavigationBarIconBrightness: isEffectiveDark ? Brightness.light : Brightness.dark,
          ),
          child: MaterialApp(
            title: 'DefogMind: Screen Time & Focus',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: currentThemeMode,
            home: _isChecking
                ? const _BrandedSplashScreen()
                : (_needsOnboarding
                    ? const OnboardingDisclosureScreen()
                    : const HomeDashboard()),
          ),
        );
      },
    );
  }
}

class _BrandedSplashScreen extends StatelessWidget {
  const _BrandedSplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Simple Clean Brain Logo (Larger, no circle border or extra effects)
                  Image.asset(
                    'assets/images/app_logo.png',
                    width: 170,
                    height: 170,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),

                  // App Title
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Defog',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        TextSpan(
                          text: 'Mind',
                          style: TextStyle(
                            color: AppTheme.mint,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'Clear Mind • Focused Life',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Lightweight Linear Loading Indicator
                  SizedBox(
                    width: 140,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        backgroundColor: AppTheme.surfaceCard,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.mint),
                        minHeight: 3.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Preparing focus engine...',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Brand Footnote
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: Text(
                  'SCREEN TIME & DIGITAL WELLBEING',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
